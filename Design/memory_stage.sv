// =============================================================================
// memory_stage.sv
// -----------------------------------------------------------------------------
// Memory stage of the RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Access data memory for load and store operations
//   - Pass through control signals and data to write-back stage
//   - Handle byte/halfword/word(/doubleword) loads and stores via funct3:
//     store lanes and byte enables, load alignment and sign/zero extension
//   - Access the D-cache only for real loads and stores
//   - Execute the A extension: LR/SC with a one-entry reservation, and AMO*
//     as a read-modify-write of the D-cache (read, then write, 2+ cycles)
//
// A extension (single in-order hart, blocking cache, so every access is
// atomic and in order; aq/rl need no action):
//   - Reservation: LR sets {ResValid, ResAddr}; SC succeeds iff ResValid and
//     the address equals ResAddr; every SC clears it. Traps and MRET do not
//     clear it (Spike's policy, so the lock-step stays exact; the kernel
//     drops a stale reservation itself with an SC on its trap-return path).
//   - AMO*: the read half holds CacheHitM low for one more cycle so the
//     hazard unit freezes the pipeline while the write half runs.
//   - SC and AMO* are not idempotent: once their cache work is done while
//     the pipeline is still frozen (StallW, e.g. by an I-cache miss), the
//     result is latched in AtomicResult and the cache is not touched again.
//
// Instantiates:
//   - cache: L1 data cache (AXI4 master to the data memory)
//   - amo_unit: AMO* read-modify-write ALU
// =============================================================================
import shared_pkg::*;

module memory_stage
#(
    parameter int DATA_WIDTH = 32,                  // XLEN
    parameter int ADDR_WIDTH = 32,                  // Physical address width
    parameter int  CACHE_TOTAL_LINES  = 32,                          
    parameter int  CACHE_WAY          = 1,                          
    parameter int  CACHE_LINE_WORDS   = 4,                           
    parameter bit  CACHE_READ_ONLY    = 0,                         
    parameter int  CACHE_AXI_SIZE     = 4,
    parameter int  FLP_WIDTH          = FINAL_FLP_WIDTH   // FLEN
) 
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ── MEM/WB register inputs ────────────────────────────────────────────────
    input ValidM,                                   // EX/MEM holds a real instruction
    input signed [DATA_WIDTH-1:0] ALUOutM,          // Address computed by ALU
    input signed [DATA_WIDTH-1:0] WriteDataM,       // Data to store
    input [DATA_WIDTH-1:0] PCPlus4M,                // PC+4 from execute
    input gpr_t RdM,                                // Destination register
    input logic [2:0] funct3M,                      // Load/store size select
    input RegWriteM,                               // Register write enable
    input logic [DATA_WIDTH-1:0] CsrOutM,          // CSR read data
    input selector_t SelectorM,                    // Write-back data select
    input MemWriteM,                               // Memory write enable
    input MemReadM,                                // Memory read enable
    input AmoM,                                    // A extension instruction
    input amo_op_t AmoOpM,                         // A extension operation

    // ── Pipeline control from hazard unit ────────────────────────────────────
    input StallW,                                  // Hold MEM/WB

    // ── FPU inputs from execute stage ─────────────────────────────────────────
    input fpr_t RdFM,                               // FPR destination
    input logic OverflowM,                         // FPU overflow flag
    input logic UnderflowM,                        // FPU underflow flag
    input logic NaNM,                              // FPU NaN flag
    input logic InfM,                              // FPU infinity flag
    input logic ZeroM,                             // FPU zero flag
    input logic InvalidDivM,                       // Invalid division flag
    input logic [FLP_WIDTH-1:0] FPUOutM,           // FPU result
    input move_operation_t MoveOperationM,         // FPU move operation
    input FPURegWriteM,                             // FPR write enable

    // ── Outputs to write-back stage ───────────────────────────────────────────
    output logic ValidW,                                // MEM/WB holds a real instruction
    output logic signed [DATA_WIDTH-1:0] ReadDataW,    // Loaded data
    output gpr_t RdW,                                   // Destination register
    output logic RegWriteW,                             // Register write enable
    output selector_t SelectorW,                        // Write-back select
    output logic [DATA_WIDTH-1:0] PCPlus4W,             // PC+4 to WB
    output logic [DATA_WIDTH-1:0] CsrOutW,             // CSR data to WB
    output logic signed [DATA_WIDTH-1:0] ALUOutW,     // ALU result to WB

    // ── FPU outputs to write-back stage ───────────────────────────────────────
    output fpr_t RdFW,                                  // FPR destination
    output logic OverflowW,                            // FPU overflow flag
    output logic UnderflowW,                            // FPU underflow flag
    output logic NaNW,                                 // FPU NaN flag
    output logic InfW,                                 // FPU infinity flag
    output logic ZeroW,                                // FPU zero flag
    output logic InvalidDivW,                           // Invalid division flag
    output logic [FLP_WIDTH-1:0] FPUOutW,             // FPU result
    output move_operation_t MoveOperationW,            // FPU move operation
    output logic FPURegWriteW,                          // FPR write enable

    // ── AXI4 master interface: write address channel ─────────────────────────
    output logic [ADDR_WIDTH-1:0] MAWAddr,
    output logic [7:0]            MAWLen,
    output logic [CACHE_AXI_SIZE-1:0]   MAWSize,
    output axi_burst_t            MAWBurst,
    output logic                  MAWValid,
    input  logic                  MAWReady,

    // ── AXI4 master interface: write data channel ────────────────────────────
    output logic [DATA_WIDTH-1:0] MWData,
    output logic [(DATA_WIDTH/8)-1:0] MWStrb,
    output logic                  MWLast,
    output logic                  MWValid,
    input  logic                  MWReady,

    // ── AXI4 master interface: write response channel ────────────────────────
    output logic                  MBReady,
    input  axi_resp_t             MBResp,
    input  logic                  MBValid,

    // ── AXI4 master interface: read address channel ──────────────────────────
    output logic [ADDR_WIDTH-1:0] MARAddr,
    output logic [7:0]            MARLen,
    output logic [CACHE_AXI_SIZE-1:0]   MARSize,
    output axi_burst_t            MARBurst,
    output logic                  MARValid,
    input  logic                  MARReady,

    // ── AXI4 master interface: read data channel ─────────────────────────────
    output logic                  MRReady,
    input  logic [DATA_WIDTH-1:0] MRRData,
    input  axi_resp_t             MRRResp,
    input  logic                  MRRLast,
    input  logic                  MRRValid,

    // ── Cache Response Signals ─────────────────────────
    output logic                 CacheHitM                     // Cache hit signal for stalling logic
);

    localparam int DATA_BYTES = DATA_WIDTH / 8;
    localparam int BYTE_OFF_W = $clog2(DATA_BYTES);

    // ─── Internal wires – data memory interface ──────────────────────────────
    logic [DATA_WIDTH-1:0] ReadDataM;           // Word returned by the cache
    logic [DATA_WIDTH-1:0] LoadDataM;           // Aligned, extended load value
    logic [DATA_WIDTH-1:0] StoreDataM;          // Store data replicated over the lanes
    logic [DATA_BYTES-1:0] ByteEnM;             // Store byte enables
    logic [BYTE_OFF_W-1:0] ByteOffsetM;         // Byte offset inside the word
    logic [DATA_WIDTH-1:0] ShiftedM;            // Loaded word shifted down to byte 0

    // ─── Internal wires – A extension ────────────────────────────────────────
    logic IsLrM, IsScM, IsRmwM;                 // Which atomic is in MEM
    logic ScOkM;                                // SC holds a matching reservation
    logic CacheReadEnM, CacheWriteEnM;          // D-cache access of this cycle
    logic CacheHitC;                            // Raw D-cache hit
    logic RmwReadDoneM;                         // AMO* read half completes
    logic AtomicDoneNowM;                       // SC / AMO* write completes
    logic [DATA_WIDTH-1:0] AmoNewM;             // Value an AMO* writes
    logic [DATA_WIDTH-1:0] StoreSrcM;           // Store data before lane replication
    logic [DATA_WIDTH-1:0] ResultDataM;         // Value loaded into ReadDataW
    logic ResValid;                             // Reservation valid
    logic [DATA_WIDTH-1:0] ResAddr;             // Reserved address
    logic AmoWritePhase;                        // AMO* read half done, write next
    logic AtomicDone;                           // SC / AMO* done, waiting for MEM/WB
    logic [DATA_WIDTH-1:0] AtomicResult;        // AMO* old value / SC status

    // ─── Load alignment and sign/zero extension ──────────────────────────────
    always_comb
    begin
        ByteOffsetM = ALUOutM[BYTE_OFF_W-1:0];
        ShiftedM = ReadDataM >> (8 * ByteOffsetM);
        case(load_store_t'(funct3M))
            B:       LoadDataM = DATA_WIDTH'(signed'(ShiftedM[7:0]));
            HW:      LoadDataM = DATA_WIDTH'(signed'(ShiftedM[15:0]));
            W:       LoadDataM = DATA_WIDTH'(signed'(ShiftedM[31:0]));
            BU:      LoadDataM = DATA_WIDTH'(ShiftedM[7:0]);
            HWU:     LoadDataM = DATA_WIDTH'(ShiftedM[15:0]);
            WU:      LoadDataM = DATA_WIDTH'(ShiftedM[31:0]);
            default: LoadDataM = ShiftedM;                  // LD (RV64)
        endcase
    end

    // ─── Store lane replication and byte enables ─────────────────────────────
    always_comb
    begin
        StoreDataM = StoreSrcM;
        ByteEnM = '1;
        case(load_store_t'(funct3M))
            B:       begin
                        StoreDataM = {DATA_BYTES{StoreSrcM[7:0]}};
                        ByteEnM = DATA_BYTES'(1) << ByteOffsetM;
                     end
            HW:      begin
                        StoreDataM = {(DATA_BYTES/2){StoreSrcM[15:0]}};
                        ByteEnM = DATA_BYTES'(2'b11) << ByteOffsetM;
                     end
            W:       begin
                        StoreDataM = {(DATA_BYTES/4){StoreSrcM[31:0]}};
                        ByteEnM = DATA_BYTES'(4'b1111) << ByteOffsetM;
                     end
            default: begin                                  // SD (RV64)
                        StoreDataM = StoreSrcM;
                        ByteEnM = '1;
                     end
        endcase
    end

    // ─── A extension: access control ─────────────────────────────────────────
    always_comb
    begin
        IsLrM = AmoM && (AmoOpM == AMO_LR); // Load-Reserved instruction
        IsScM = AmoM && (AmoOpM == AMO_SC); // Store-Conditional instruction
        IsRmwM = AmoM && !IsLrM && !IsScM; // Read-Modify-Write AMO* instruction
        ScOkM = ResValid && (ResAddr == ALUOutM);

        // AMO* reads first, then writes; a failed SC does not write; nothing
        // touches the cache again once an SC / AMO* is done.
        CacheReadEnM = MemReadM && !AtomicDone && !(IsRmwM && AmoWritePhase);
        CacheWriteEnM = MemWriteM && !AtomicDone &&
                        (IsRmwM ? AmoWritePhase : (!IsScM || ScOkM));

        RmwReadDoneM = IsRmwM && !AtomicDone && !AmoWritePhase && CacheHitC;
        AtomicDoneNowM = (IsScM || (IsRmwM && AmoWritePhase)) && !AtomicDone && CacheHitC;

        // The read half of an AMO* is never the last cycle in MEM
        CacheHitM = CacheHitC && !(IsRmwM && !AmoWritePhase && !AtomicDone);

        StoreSrcM = IsRmwM ? AmoNewM : WriteDataM;

        if(IsRmwM || AtomicDone)
            ResultDataM = AtomicResult;
        else if(IsScM)
            ResultDataM = DATA_WIDTH'(!ScOkM);         // 0 = success, 1 = failure
        else
            ResultDataM = LoadDataM;
    end

    // ─── A extension: reservation and RMW sequencing ─────────────────────────
    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            ResValid <= 1'b0;
            ResAddr <= '0;
            AmoWritePhase <= 1'b0;
            AtomicDone <= 1'b0;
            AtomicResult <= '0;
        end
        else
        begin
            if (RmwReadDoneM)
            begin
                AmoWritePhase <= 1'b1;
                AtomicResult <= LoadDataM;             // Old value = rd result
            end

            if (AtomicDoneNowM)
            begin
                AmoWritePhase <= 1'b0;
                AtomicDone <= StallW;                  // Frozen: keep the result
                if (IsScM)
                    AtomicResult <= DATA_WIDTH'(!ScOkM);
            end
            else if (!StallW)
            begin
                AtomicDone <= 1'b0;
            end

            if (IsLrM && CacheHitC)
            begin
                ResValid <= 1'b1;
                ResAddr <= ALUOutM;
            end
            else if (IsScM && AtomicDoneNowM)
            begin
                ResValid <= 1'b0;
            end
        end
    end

    // ─── amo_unit: AMO* read-modify-write ALU ────────────────────────────────
    amo_unit #(.DATA_WIDTH(DATA_WIDTH)) AmoUnit
    (
        .AmoOp(AmoOpM),
        .IsWord(load_store_t'(funct3M) == W),
        .OldData(AtomicResult),
        .SrcData(WriteDataM),
        .NewData(AmoNewM)
    );

    cache #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TOTAL_LINES(CACHE_TOTAL_LINES),
        .WAY(CACHE_WAY),
        .LINE_WORDS(CACHE_LINE_WORDS),
        .READ_ONLY(0),
        .AXI_SIZE(CACHE_AXI_SIZE)
    ) DCache (
                    
        .clk(clk),
        .rst(rst),
        .CPUAddr(ALUOutM[ADDR_WIDTH-1:0]), 
        .CPUWriteData(StoreDataM),
        .CPUByteEn(ByteEnM),
        .CPUWriteEn(CacheWriteEnM),
        .CPUReadEn(CacheReadEnM),
        .CPUReadData(ReadDataM),
        .CacheHit(CacheHitC),    
        .MAWAddr(MAWAddr),
        .MAWLen(MAWLen),
        .MAWSize(MAWSize),
        .MAWBurst(MAWBurst),
        .MAWValid(MAWValid),
        .MAWReady(MAWReady),
        .MWData(MWData),
        .MWStrb(MWStrb),
        .MWLast(MWLast),
        .MWValid(MWValid),
        .MWReady(MWReady),
        .MBReady(MBReady),
        .MBResp(MBResp),
        .MBValid(MBValid),
        .MARAddr(MARAddr),
        .MARLen(MARLen),
        .MARSize(MARSize),
        .MARBurst(MARBurst),
        .MARValid(MARValid),
        .MARReady(MARReady),
        .MRReady(MRReady),
        .MRRData(MRRData),
        .MRRResp(MRRResp),
        .MRRLast(MRRLast),
        .MRRValid(MRRValid)    
        );


    // ─── MEM/WB pipeline register ─────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            ValidW <= 1'b0;
            ReadDataW <= '0;
            RegWriteW <= 1'b0;
            SelectorW <= ALUToReg;
            RdW <= zero;
            ALUOutW <= '0;
            PCPlus4W <= '0;
            CsrOutW <= '0;
            RdFW <= f0;
            OverflowW <= 1'b0;
            UnderflowW <= 1'b0;
            NaNW <= 1'b0;
            InfW <= 1'b0;
            ZeroW <= 1'b0;
            InvalidDivW <= 1'b0;
            FPUOutW <= '0;
            MoveOperationW <= FPUToFPU;
            FPURegWriteW <= 1'b0;
        end
        else if (!StallW)
        begin
            ValidW <= ValidM;
            ReadDataW <= ResultDataM;
            RegWriteW <= RegWriteM;
            SelectorW <= SelectorM;
            RdW <= RdM;
            PCPlus4W <= PCPlus4M;
            ALUOutW <= ALUOutM;
            CsrOutW <= CsrOutM;
            RdFW <= RdFM;
            OverflowW <= OverflowM;
            UnderflowW <= UnderflowM;
            NaNW <= NaNM;
            InfW <= InfM;
            ZeroW <= ZeroM;
            InvalidDivW <= InvalidDivM;
            FPUOutW <= FPUOutM;
            MoveOperationW <= MoveOperationM;
            FPURegWriteW <= FPURegWriteM;
        end
    end
    
endmodule
