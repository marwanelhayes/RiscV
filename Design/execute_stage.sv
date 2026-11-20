// =============================================================================
// execute_stage.sv
// -----------------------------------------------------------------------------
// Execute stage of the RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Execute ALU operations (arithmetic, logical, shift, compare)
//   - Execute floating-point operations via FPU
//   - Run the multi-cycle divider (DIV/DIVU/REM/REMU) and hold EX while it works
//   - Handle branch evaluation and jump targets
//   - Perform data forwarding from later pipeline stages
//   - Manage CSR read/write operations and take traps in the same cycle
//   - Compute memory addresses for loads/stores and the JALR target
//   - Run RV64 word operations (OP-32 / OP-IMM-32) when DATA_WIDTH = 64
//
// Instantiates:
//   - risc_alu: integer ALU
//   - risc_fpu: floating-point unit
//   - non_restoring_divider: iterative integer divider
//   - risc_mux2, risc_mux3, risc_mux4: operand selection muxes
//   - csr_file: control and status register file
// =============================================================================
import shared_pkg::*;

module execute_stage
#(
    parameter int DATA_WIDTH = 32,                  // XLEN
    parameter int ADDR_WIDTH = 32,                  // Physical address width
    parameter int ALU_SUB_CONTROL_WIDTH = 2,
    parameter int STAGES = 4,
    parameter int FLP_WIDTH = FINAL_FLP_WIDTH       // FLEN
)
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ── EX/MEM register inputs ────────────────────────────────────────────────
    input ValidE,                              // ID/EX holds a real instruction
    input signed [DATA_WIDTH-1:0] RD1E,        // GPR rs1 value
    input signed [DATA_WIDTH-1:0] RD2E,        // GPR rs2 value
    input signed [DATA_WIDTH-1:0] SignImmE,    // Sign-extended immediate
    input [DATA_WIDTH-1:0] PCPlus4E,           // PC+4 from decode
    input [DATA_WIDTH-1:0] PCBranchE,          // PC + immediate from decode
    input alu_operation_t ALUControlE,         // ALU operation select
    input logic [2:0] funct3E,                 // funct3 field
    input BranchE,                             // Branch instruction flag
    input JumpE,                               // Jump instruction flag
    input JalrE,                               // Jump target from rs1 (JALR)
    input AuipcE,                              // ALU operand A is the PC
    input WordOpE,                             // RV64 32-bit operation
    input AmoE,                                // A extension instruction
    input amo_op_t AmoOpE,                     // A extension operation

    // ── Forwarding inputs ─────────────────────────────────────────────────────
    input [2:0] ForwardAE,                     // Forward select for operand A
    input [2:0] ForwardBE,                     // Forward select for operand B
    input signed [DATA_WIDTH-1:0] ResultW,     // Write-back result

    // ── Register file interface ───────────────────────────────────────────────
    input gpr_t Rs1E,                          // Source register 1 index
    input gpr_t RdE,                           // Destination register index
    input RegWriteE,                          // Register write enable

    // ── CSR interface ─────────────────────────────────────────────────────────
    input CsrAccessE,                          // CSR access enable
    input csr_t CsrOperationE,                 // CSR operation type
    input csr_index_t CsrIndexE,              // CSR register address
    input TimerInterrupt,                     // Timer interrupt pending
    input ExternalInterrupt,                   // External interrupt pending
    input SoftwareInterrupt,                  // Software interrupt pending
    input [63:0] MTime,                       // Machine timer (time/timeh)

    // ── Control signals ───────────────────────────────────────────────────────
    input selector_t SelectorE,                // Write-back data select
    input ALUSrcE,                            // ALU operand B select
    input MemWriteE,                          // Memory write enable
    input MemReadE,                           // Memory read enable

    // ── Pipeline control from hazard unit ────────────────────────────────────
    input StallE,                             // EX holds its instruction
    input StallM,                             // Hold EX/MEM
    input FlushM,                             // Load a bubble into EX/MEM

    // ── Special instructions ─────────────────────────────────────────────────
    input MRetE,                               // MRET instruction flag
    input FenceIE,                             // Instruction-fetch fence in EX
    input EcallE,                              // ECALL instruction flag
    input EbreakE,                             // EBREAK instruction flag
    input WfiE,                                // WFI instruction flag
    input IllegaleInstructionE,                // Illegal instruction flag

    // ── FPR inputs from decode stage ─────────────────────────────────────────
    input fpr_t RdFE,                          // FPR destination index
    input [FLP_WIDTH-1:0] RD1FE,              // FPR rs1 value
    input [FLP_WIDTH-1:0] RD2FE,              // FPR rs2 value
    input fpu_operation_t FPUControlE,         // FPU operation type
    input round_mode_t RoundModeE,             // Rounding mode
    input FPURegWriteE,                        // FPR write enable
    input FPUValidE,                          // Valid FPU operation
    input move_operation_t MoveOperationE,    // FPU move operation type
    input fpr_t Rs1FE,                         // FPR source register 1 index
    input fpr_t Rs2FE,                         // FPR source register 2 index

    // ── FPU forwarding inputs ────────────────────────────────────────────────
    input logic [FLP_WIDTH-1:0] FPUOutW,       // FPU write-back result
    input logic [1:0] ForwardFloatingAE,      // FPU forward select A
    input logic [1:0] ForwardFloatingBE,      // FPU forward select B

    // ── Outputs to memory stage ─────────────────────────────────────────────
    output logic ValidM,                              // EX/MEM holds a real instruction
    output logic FenceIM,                             // Instruction-fetch fence in MEM
    output logic FenceIStartE,                        // Accepted fence squashes younger instructions
    output logic signed [DATA_WIDTH-1:0] ALUOutM,      // ALU result
    output logic signed [DATA_WIDTH-1:0] WriteDataM,   // Data to store
    output gpr_t RdM,                                 // Destination register
    output logic PCSrcE,                              // Taken branch/jump redirect
    output logic [DATA_WIDTH-1:0] PCTargetE,          // Branch/jump target
    output logic RegWriteM,                          // Register write enable
    output logic [DATA_WIDTH-1:0] PCPlus4M,          // PC+4 to next stage
    output selector_t SelectorM,                     // Write-back select
    output logic [2:0] funct3M,                      // funct3 to memory
    output logic [DATA_WIDTH-1:0] CsrOutM,           // CSR read data
    output logic MemWriteM,                          // Memory write enable
    output logic MemReadM,                           // Memory read enable
    output logic AmoM,                               // A extension instruction
    output amo_op_t AmoOpM,                          // A extension operation

    // ── Trap and CSR outputs ────────────────────────────────────────────────
    output logic TrapIsSet,                         // Trap/MRET redirect this cycle
    output logic [DATA_WIDTH-1:0] CsrOutPC,          // Trap vector or mepc

    // ── FPU outputs to memory stage ─────────────────────────────────────────
    output fpr_t RdFM,                              // FPR destination
    output logic OverflowM,                         // Floating-point overflow
    output logic UnderflowM,                        // Floating-point underflow
    output logic NaNM,                              // Not-a-Number flag
    output logic InfM,                              // Infinity flag
    output logic ZeroM,                            // Zero result flag
    output logic InvalidDivM,                       // Invalid division flag
    output logic [FLP_WIDTH-1:0] FPUOutM,           // FPU result
    output logic FPURegWriteM,                     // FPR write enable
    output move_operation_t MoveOperationM,         // FPU move operation
    output logic FPUBusyE,                          // FPU busy flag
    output logic FPUDoneE,                          // FPU result valid this cycle
    output logic DivWaitE,                          // Divide in EX, result not ready
    output logic WfiStallE                          // Hold EX after WFI until an interrupt is pending
);

    localparam bit IS_RV64 = (DATA_WIDTH == 64);
    localparam int LOG_WIDTH = $clog2(DATA_WIDTH);

    logic signed [DATA_WIDTH:0] ALUOutE;
    logic signed [DATA_WIDTH-1:0] SrcAE;              // Forwarded rs1
    logic signed [DATA_WIDTH-1:0] SrcAALUE;           // ALU operand A (rs1, PC or word-conditioned)
    logic signed [DATA_WIDTH-1:0] SrcBE;              // Selected operand B
    logic signed [DATA_WIDTH-1:0] SrcBALUE;           // ALU operand B (word-conditioned)
    logic signed [DATA_WIDTH-1:0] WriteDataE;         // Forwarded rs2
    logic signed [DATA_WIDTH-1:0] ResultE;            // Integer result of the instruction
    logic signed [DATA_WIDTH-1:0] ResultM;            // Value the M instruction will write
    logic branch_true;
    logic TakenE;                                     // Branch/jump is taken
    logic Commit;                                     // EX instruction advances this cycle
    logic TrapTaken;                                  // EX instruction is squashed by a trap
    priv_mode_t PrivModeE;                            // Current privilege mode
    traps_t TrapsE;
    logic [DATA_WIDTH-1:0] TvalE;                     // Trap value of the exception
    logic [FLP_WIDTH-1:0] FPUInAE,FPUInBE, FPUInAETemp;
    logic [FLP_WIDTH-1:0] FPUResultE;
    logic FPUOverflowE, FPUUnderflowE, FPUNaNE, FPUInfE, FPUZeroE, FPUInvalidDivE;
    logic [DATA_WIDTH-1:0] CsrReadE;
    logic [DATA_WIDTH-1:0] PCE;
    logic [DATA_WIDTH-1:0] AddressE;                  // Load/store address
    logic DivE;                                       // Valid divide/remainder in EX
    logic DivDoneE;                                   // Divider result valid
    logic [DATA_WIDTH-1:0] QuotientE, RemainderE;     // Divider results
    round_mode_t DynRoundMode,ActualRoundMode;

    risc_alu #(.DATA_WIDTH(DATA_WIDTH)) ALU
    (
        .SrcA(SrcAALUE),
        .SrcB(SrcBALUE),
        .alu_branch_control(branch_t'(funct3E)),
        .alu_control(ALUControlE),
        .Y(ALUOutE),
        .branch_true(branch_true)
    );

    // The FPU is a blocking EX-stage unit: an FP instruction stays in EX
    // (the hazard unit stalls it) until done, then moves on with its result.
    risc_fpu #(.PRECISION(SINGLE),.STAGES(STAGES)) FPU
    (
        .clk(clk),
        .rst(rst),
        .valid(FPUValidE & ValidE & !FPUDoneE),
        .hold(StallE),                // A freeze in the done cycle keeps the result
        .InA(FPUInAE),
        .InB(FPUInBE),
        .round_mode(ActualRoundMode),
        .operation(FPUControlE),
        .Overflow(FPUOverflowE),
        .Underflow(FPUUnderflowE),
        .RdF(RdFE),
        .NaN(FPUNaNE),
        .Inf(FPUInfE),
        .Zero(FPUZeroE),
        .InvalidDiv(FPUInvalidDivE),
        .Result(FPUResultE),
        .busy(FPUBusyE),
        .done(FPUDoneE),
        .RdFOut(),
        .RegWriteOut(),
        .RegWrite(FPURegWriteE),
        .MoveOperation(MoveOperationE),
        .MoveOperationOut()
    );

    // The divider is a blocking EX-stage unit like the FPU: a divide stays in
    // EX (the hazard unit stalls it) until done, then moves on with its result.
    // It takes its operands in the first cycle, while forwarding is current.
    non_restoring_divider #(.WIDTH(DATA_WIDTH)) DIVIDER
    (
        .clk(clk),
        .rst(rst),
        .start(DivE),
        .hold(StallE),                // A freeze in the done cycle keeps the result
        .done(DivDoneE),
        .sign(ALUControlE inside {DIV, REM}),
        .dividend(SrcAALUE),
        .divisor(SrcBALUE),
        .quotient(QuotientE),
        .remainder(RemainderE)
    );


    risc_mux4 #(.DATA_WIDTH(DATA_WIDTH)) M1 
    (
        .IN_1(RD1E),
        .IN_2(ResultW),
        .IN_3(ResultM),
        .IN_4('0),
        .IN_5('0),
        .IN_6('0),
        .IN_7('0),
        .IN_8('0),
        .sel(ForwardAE),
        .Y(SrcAE)
    );


    risc_mux4 #(.DATA_WIDTH(DATA_WIDTH)) M2 
    (
        .IN_1(RD2E),
        .IN_2(ResultW),
        .IN_3(ResultM),
        .IN_4('0),
        .IN_5('0),
        .IN_6('0),
        .IN_7('0),
        .IN_8('0),
        .sel(ForwardBE),
        .Y(WriteDataE)
    );

    risc_mux2 #(.DATA_WIDTH(DATA_WIDTH)) M3 
    (
        .IN_1(WriteDataE),
        .IN_2(SignImmE),
        .sel(ALUSrcE),
        .Y(SrcBE)
    );

    risc_mux3 #(.DATA_WIDTH(FLP_WIDTH)) F1
    (
        .IN_1(RD1FE),
        .IN_2(FPUOutW),
        .IN_3(FPUOutM),
        .IN_4('0),
        .sel(ForwardFloatingAE),
        .Y(FPUInAETemp)
    );

    risc_mux3 #(.DATA_WIDTH(FLP_WIDTH)) F2
    (
        .IN_1(RD2FE),
        .IN_2(FPUOutW),
        .IN_3(FPUOutM),
        .IN_4('0),
        .sel(ForwardFloatingBE),
        .Y(FPUInBE)
    );


    csr_file #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) CSR 
    (
        .clk(clk),
        .rst(rst),
        .CsrOperation(CsrOperationE),
        .Rs(Rs1E),
        .Traps(TrapsE),
        .mret(MRetE),
        .Wfi(WfiE),
        .MTime(MTime),
        .PC(PCE),
        .Address(TvalE),
        .CsrAccess(CsrAccessE),
        .Commit(Commit),
        .ExternalInterrupt(ExternalInterrupt),
        .TimerInterrupt(TimerInterrupt),
        .SoftwareInterrupt(SoftwareInterrupt),
        .CsrIn($unsigned(SrcAE)),
        .CsrIndex(CsrIndexE),
        .CsrOutPC(CsrOutPC),
        .CsrOut(CsrReadE),
        .TrapIsSet(TrapIsSet),
        .TrapTaken(TrapTaken),
        .RoundingMode(DynRoundMode),
        .PrivMode(PrivModeE),
        .WfiStall(WfiStallE)
    );

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            ValidM <= 0;
            FenceIM <= 0;
            RegWriteM <= 0;
            SelectorM <= ALUToReg;
            MemWriteM <= 0;
            MemReadM <= 0;
            AmoM <= 0;
            AmoOpM <= AMO_ADD;
            ALUOutM <= 0;
            WriteDataM <= 0;
            RdM <= zero;
            funct3M <= 0;
            PCPlus4M <= 0;
            CsrOutM <= 0;
            RdFM <= f0;
            FPUOutM <= 0;
            FPURegWriteM <= 0;
            MoveOperationM <= FPUToFPU;
            OverflowM <= 0;
            UnderflowM <= 0;
            NaNM <= 0;
            InfM <= 0;
            ZeroM <= 0;
            InvalidDivM <= 0;
        end
        else if (FlushM)
        begin
            ValidM <= 0;
            FenceIM <= 0;
            RegWriteM <= 0;
            SelectorM <= ALUToReg;
            MemWriteM <= 0;
            MemReadM <= 0;
            AmoM <= 0;
            AmoOpM <= AMO_ADD;
            ALUOutM <= 0;
            WriteDataM <= 0;
            RdM <= zero;
            funct3M <= 0;
            PCPlus4M <= 0;
            CsrOutM <= 0;
            RdFM <= f0;
            FPUOutM <= 0;
            FPURegWriteM <= 0;
            MoveOperationM <= FPUToFPU;
            OverflowM <= 0;
            UnderflowM <= 0;
            NaNM <= 0;
            InfM <= 0;
            ZeroM <= 0;
            InvalidDivM <= 0;
        end
        else if (!StallM)
        begin
            ValidM <= ValidE;
            FenceIM <= FenceIStartE;
            RegWriteM <= RegWriteE;
            SelectorM <= SelectorE;
            MemWriteM <= MemWriteE;
            MemReadM <= MemReadE;
            AmoM <= AmoE;
            AmoOpM <= AmoOpE;
            ALUOutM <= ResultE;
            WriteDataM <= WriteDataE;
            RdM <= RdE;
            funct3M <= funct3E;
            PCPlus4M <= PCPlus4E;
            CsrOutM <= CsrReadE;
            RdFM <= RdFE;
            FPUOutM <= FPUResultE;
            FPURegWriteM <= FPURegWriteE;
            MoveOperationM <= MoveOperationE;
            OverflowM <= FPUOverflowE;
            UnderflowM <= FPUUnderflowE;
            NaNM <= FPUNaNE;
            InfM <= FPUInfE;
            ZeroM <= FPUZeroE;
            InvalidDivM <= FPUInvalidDivE;
        end
    end

    // ─── ALU operands ─────────────────────────────────────────────────────────
    // RV64 word operations (OP-32 / OP-IMM-32) work on the low 32 bits: the
    // operands are sign- (or, for SRLW/DIVUW/REMUW, zero-) extended from bit
    // 31, shifts use shamt[4:0], and the result is sign-extended from bit 31.
    always_comb
    begin
        SrcAALUE = AuipcE ? signed'(PCE) : SrcAE;
        SrcBALUE = SrcBE;
        if(IS_RV64 && WordOpE)
        begin
            if(ALUControlE inside {SRL, DIVU, REMU})
                SrcAALUE = signed'(DATA_WIDTH'(SrcAE[31:0]));
            else
                SrcAALUE = DATA_WIDTH'(signed'(SrcAE[31:0]));
            if(ALUControlE inside {DIVU, REMU})
                SrcBALUE = signed'(DATA_WIDTH'(SrcBE[31:0]));
            else if(ALUControlE inside {SLL, SRL, SRA})
                SrcBALUE = DATA_WIDTH'(SrcBE[4:0]);
            else
                SrcBALUE = DATA_WIDTH'(signed'(SrcBE[31:0]));
        end
    end

    // ─── Instruction result ──────────────────────────────────────────────────
    // FP instructions that write an integer register carry their result in
    // the ALU result field, so forwarding and write-back need no FPU path.
    always_comb
    begin
        DivE = ValidE && (ALUControlE inside {DIV, DIVU, REM, REMU});
        DivWaitE = DivE && !DivDoneE;
        ResultE = ALUOutE[DATA_WIDTH-1:0];
        if(ALUControlE inside {DIV, DIVU})
            ResultE = QuotientE;
        else if(ALUControlE inside {REM, REMU})
            ResultE = RemainderE;
        if(IS_RV64 && WordOpE)
            ResultE = DATA_WIDTH'(signed'(ResultE[31:0]));
        if(MoveOperationE == FPUToReg)
            ResultE = DATA_WIDTH'(signed'(FPUResultE[31:0]));
        AddressE = ALUOutE[DATA_WIDTH-1:0];
    end

    // Value the instruction in M will write back (forwarding source)
    always_comb
    begin
        case(SelectorM)
            PCToReg:  ResultM = PCPlus4M;
            CSRToReg: ResultM = CsrOutM;
            default:  ResultM = ALUOutM;
        endcase
    end

    // ─── Control flow ─────────────────────────────────────────────────────────
    always_comb
    begin
        PCE = PCPlus4E - DATA_WIDTH'(4);
        PCTargetE = JalrE ? {AddressE[DATA_WIDTH-1:1], 1'b0} : PCBranchE;
        TakenE = (BranchE & branch_true) | JumpE;
        Commit = ValidE && !StallE;
        PCSrcE = Commit && TakenE && !TrapTaken;
    end

    assign FenceIStartE = Commit && FenceIE && !TrapIsSet;


    // ─── Synchronous exceptions of the EX instruction ───────────────────────
    always_comb
    begin
        TrapsE = NoTraps;
        TvalE = '0;
        if(IllegaleInstructionE)
        begin
            TrapsE = IllegalInstructionOrHypervisorSoftwareInterrupt;
        end
        else if(TakenE && PCTargetE[1])
        begin
            TrapsE = InstructionAddressMisalignedOrUserSoftwareInterrupt;
            TvalE = PCTargetE;
        end
        else if(EbreakE)
        begin
            TrapsE = BreakpointOrMachineSoftwareInterrupt;
        end
        else if(EcallE)
        begin
            TrapsE = (PrivModeE == UserMode) ? EcallUOrUserExternalInterrupt : EcallMOrMachineExternalInterrupt;
        end
        else if(MemReadE && !MemWriteE)                   // AMO* (read + write) traps as a store
        begin
            if(((load_store_t'(funct3E) == HW) || (load_store_t'(funct3E) == HWU)) && AddressE[0])
                TrapsE = LoadAddressMisalignedOrUserSoftwareInterrupt;
            else if(((load_store_t'(funct3E) == W) || (load_store_t'(funct3E) == WU)) && (|AddressE[1:0]))
                TrapsE = LoadAddressMisalignedOrUserSoftwareInterrupt;
            else if((load_store_t'(funct3E) == D) && (|AddressE[2:0]))
                TrapsE = LoadAddressMisalignedOrUserSoftwareInterrupt;
            TvalE = AddressE;
        end
        else if(MemWriteE)
        begin
            if((load_store_t'(funct3E) == HW) && AddressE[0])
                TrapsE = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
            else if((load_store_t'(funct3E) == W) && (|AddressE[1:0]))
                TrapsE = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
            else if((load_store_t'(funct3E) == D) && (|AddressE[2:0]))
                TrapsE = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
            TvalE = AddressE;
        end
    end

    always_comb
    begin
        FPUInAE = FPUInAETemp;
        if(MoveOperationE == RegToFPU)
            FPUInAE = SrcAE[FLP_WIDTH-1:0];
    end

    always_comb
    begin
        ActualRoundMode = RoundModeE;
        if(RoundModeE == DYN)
        begin
            ActualRoundMode = DynRoundMode;
        end
    end
endmodule
