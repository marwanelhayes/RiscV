// =============================================================================
// decode_stage.sv
// -----------------------------------------------------------------------------
// Instruction Decode stage of the RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Decode instruction fields (opcode, funct3, funct7, registers, immediates)
//   - Generate control signals for execution stage
//   - Read from integer and floating-point register files
//   - Compute PC-relative targets (branches, JAL, AUIPC) at XLEN width
//   - Handle special instructions: CSR, ECALL, EBREAK, MRET, WFI (NOP)
//   - Flag illegal encodings (opcode, funct3/funct7, SYSTEM, read-only CSR writes)
//
// Instantiates:
//   - risc_control_unit: generates control signals based on instruction
//   - risc_reg_file: integer register file
//   - fp_reg_file: floating-point register file
// =============================================================================
import shared_pkg::*;

module decode_stage
#(
    parameter int DATA_WIDTH = 32,                  // XLEN
    parameter int ADDR_WIDTH = 32,                  // Physical address width (unused here)
    parameter int ALU_SUB_CONTROL_WIDTH = 2,
    parameter int FLP_WIDTH = FINAL_FLP_WIDTH       // FLEN
)
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ── ID/EX register inputs ─────────────────────────────────────────────────
    input [DATA_WIDTH-1:0] PCPlus4D,        // PC+4 from fetch stage
    input [INSTR_WIDTH-1:0] InstructionD,   // Fetched instruction
    input ValidD,                           // IF/ID holds a real instruction

    // ── Write-back data from WB stage ────────────────────────────────────────
    input gpr_t RdW,                        // Destination register (GPR)
    input RegWriteW,                        // GPR write enable
    input signed [DATA_WIDTH-1:0] ResultW, // GPR write-back data
    input fpr_t RdFW,                       // Destination register (FPR)
    input [FLP_WIDTH-1:0] FPUOutW,         // FPR write-back data
    input FPURegWriteW,                     // FPR write enable

    // ── Pipeline control ─────────────────────────────────────────────────────
    input FlushE,                           // Load a bubble into ID/EX
    input StallE,                           // Hold ID/EX

    // ── GPR outputs to execute stage ─────────────────────────────────────────
    output gpr_t Rs1E,                      // Source register 1 index
    output gpr_t Rs2E,                      // Source register 2 index
    output gpr_t Rs1D,                      // Current instruction rs1 (x0 if unused)
    output gpr_t Rs2D,                      // Current instruction rs2 (x0 if unused)
    output gpr_t RdE,                       // Destination register index
    output logic signed [DATA_WIDTH-1:0] RD1E,  // GPR rs1 value
    output logic signed [DATA_WIDTH-1:0] RD2E,  // GPR rs2 value

    // ── Control signals to execute stage ────────────────────────────────────
    output logic ValidE,                    // ID/EX holds a real instruction
    output logic JumpE,                     // Jump instruction flag
    output logic JalrE,                     // Jump target from rs1 (JALR)
    output alu_operation_t ALUControlE,     // ALU operation select
    output logic signed [DATA_WIDTH-1:0] SignImmE,  // Sign-extended immediate
    output logic [DATA_WIDTH-1:0] PCBranchE,        // PC + immediate (branch/JAL target, AUIPC)
    output logic RegWriteE,                 // Register write enable
    output selector_t SelectorE,             // Write-back data select
    output logic MemWriteE,                 // Memory write enable
    output logic MemReadE,                  // Memory read enable
    output logic BranchE,                   // Branch instruction flag
    output logic ALUSrcE,                   // ALU second operand select
    output logic AuipcE,                    // ALU first operand is the PC
    output logic WordOpE,                   // RV64 32-bit operation

    // ── CSR interface ─────────────────────────────────────────────────────────
    output csr_t CsrOperationE,             // CSR operation type
    output csr_index_t CsrIndexE,          // CSR register address
    output logic CsrAccessE,               // CSR access enable

    // ── Special instruction flags ────────────────────────────────────────────
    output logic EcallE,                    // ECALL instruction flag
    output logic EbreakE,                   // EBREAK instruction flag
    output logic MRetE,                     // MRET instruction flag
    output logic IllegaleInstructionE,      // Illegal instruction flag

    // ── Function field passthrough ───────────────────────────────────────────
    output logic [2:0] funct3E,             // funct3 field
    output logic [DATA_WIDTH-1:0] PCPlus4E,   // PC+4 to next stage

    // ── FPR outputs to execute stage ─────────────────────────────────────────
    output fpr_t RdFE,                      // FPR destination index
    output logic [FLP_WIDTH-1:0] RD1FE,   // FPR rs1 value
    output logic [FLP_WIDTH-1:0] RD2FE,   // FPR rs2 value
    output fpu_operation_t FPUControlE,   // FPU operation type
    output round_mode_t RoundModeE,        // Floating-point rounding mode
    output logic FPURegWriteE,             // FPR write enable
    output move_operation_t MoveOperationE,  // FPU move operation type
    output fpr_t Rs1FE,                    // FPR source register 1 index
    output fpr_t Rs2FE,                    // FPR source register 2 index
    output logic FPUValidE                 // Valid FPU operation flag
);

    // ─── Internal wires and registers – ID stage ─────────────────────────────
    // GPR read data (combinational)
    logic signed [DATA_WIDTH-1:0] RD1D;
    logic signed [DATA_WIDTH-1:0] RD2D;

    // FPR read data (combinational)
    logic [FLP_WIDTH-1:0] RD1FD;
    logic [FLP_WIDTH-1:0] RD2FD;

    // Immediate and branch computation
    logic signed [DATA_WIDTH-1:0] SignImmD;        // Sign-extended immediate
    logic [DATA_WIDTH-1:0] PCD;                    // PC of the decoded instruction
    logic [DATA_WIDTH-1:0] PCBranchD;             // PC + immediate

    // Control signals from control unit
    logic RegWriteD;
    selector_t SelectorD;
    logic MemWriteD;
    logic MemReadD;
    logic BranchD;
    logic ImmediateD;
    logic UpperD;
    logic AuipcD;
    logic ALUSrcD;
    logic StoreD;
    logic WordOpD;
    logic [2:0] funct3D;
    logic [6:0] funct7D;
    gpr_t RdD;
    fpr_t Rs1FD;
    fpr_t Rs2FD;
    fpr_t RdFD;
    alu_operation_t ALUControlD;
    fpu_operation_t FPUControlD;
    opcode_t opcodeD;
    logic JumpD;
    logic JalrD;
    csr_t CsrOperationD;
    logic CsrAccessD;
    csr_index_t CsrIndexD;
    logic MModeD;
    logic EcallD;
    logic EbreakD;
    logic MRetD;
    logic SystemIllegalD;                  // Unknown SYSTEM (funct3 = 000) encoding
    logic IllegaleInstructionD;
    logic CsrReadOnlyWriteD;               // CSR write to the read-only address space
    round_mode_t RoundModeD;
    move_operation_t MoveOperationD;
    logic FPURegWriteD;
    logic FPUValidD;

    risc_control_unit #(.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH),.DATA_WIDTH(DATA_WIDTH)) CU(
        .opcode(opcodeD),
        .funct3(funct3D),
        .funct7(funct7D),
        .BranchD(BranchD),
        .Rs2(gpr_t'(InstructionD[24:20])),
        .ALUControlD(ALUControlD),
        .ImmediateD(ImmediateD),
        .UpperD(UpperD),
        .AuipcD(AuipcD),
        .RegWriteD(RegWriteD),
        .CsrOperationD(CsrOperationD),
        .SelectorD(SelectorD),
        .MemWriteD(MemWriteD),
        .MemReadD(MemReadD),
        .ALUSrcD(ALUSrcD),
        .StoreD(StoreD),
        .CsrAccessD(CsrAccessD),
        .MModeD(MModeD),
        .JumpD(JumpD),
        .JalrD(JalrD),
        .WordOpD(WordOpD),
        .IllegaleInstructionD(IllegaleInstructionD),
        .FPUControlD(FPUControlD),
        .MoveOperationD(MoveOperationD),
        .FPURegWriteD(FPURegWriteD),
        .FPUValidD(FPUValidD)
    );

    risc_reg_file #(.DATA_WIDTH(DATA_WIDTH)) RF(
        .clk(clk),
        .rst(rst),
        .Rs1(Rs1D),
        .Rs2(Rs2D),
        .Rd(RdW),
        .WData(ResultW),
        .WE(RegWriteW),
        .RD1(RD1D),
        .RD2(RD2D)
    );

    fp_reg_file #(.DATA_WIDTH(FLP_WIDTH)) FPRF(
        .clk(clk),
        .rst(rst),
        .Rs1(Rs1FD),
        .Rs2(Rs2FD),
        .Rd(RdFW),
        .WData(FPUOutW),
        .WE(FPURegWriteW),
        .RD1(RD1FD), 
        .RD2(RD2FD)  
    );

    always_ff @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            ValidE <= 1'b0;
            Rs1E <= zero;
            Rs2E <= zero;
            RdE <= zero;
            ALUControlE <= ADD;
            RD1E <= 'b0;
            RD2E <= 'b0;
            SignImmE <= 'b0;
            PCBranchE <= 'b0;
            funct3E <= 'b0;
            RegWriteE <= 'b0;
            SelectorE <= ALUToReg; // Default selector
            MemWriteE <= 'b0;
            MemReadE <= 'b0;
            BranchE <= 'b0;
            ALUSrcE <= 'b0;
            AuipcE <= 'b0;
            WordOpE <= 'b0;
            JumpE <= 'b0;
            JalrE <= 'b0;
            CsrOperationE <= csrrw; // Default value for CSR operation
            CsrAccessE <= 0; // Default value for CSR access
            CsrIndexE <= mstatus; // Default CSR index
            PCPlus4E <= 'b0; // Default PCPlus4 value
            MRetE <= 0;
            EcallE <= 0;
            EbreakE <= 0;
            IllegaleInstructionE <= 0;
            RdFE <= f0;
            RD1FE <= 'b0;
            RD2FE <= 'b0;
            FPUControlE <= NOOPERATION;
            RoundModeE <= RNE;
            MoveOperationE <= FPUToFPU;
            FPURegWriteE <= 1'b0;
            Rs1FE <= f0;
            Rs2FE <= f0;
            FPUValidE <= 1'b0;
        end
        else if(FlushE)
        begin
            ValidE <= 1'b0;
            Rs1E <= zero;
            Rs2E <= zero;
            RdE <= zero;
            ALUControlE <= ADD;
            RD1E <= 'b0;
            RD2E <= 'b0;
            SignImmE <= 'b0;
            PCBranchE <= 'b0;
            funct3E <= 'b0;
            RegWriteE <= 'b0;
            SelectorE <= ALUToReg;
            MemWriteE <= 'b0;
            MemReadE <= 'b0;
            BranchE <= 'b0;
            ALUSrcE <= 'b0;
            AuipcE <= 'b0;
            WordOpE <= 'b0;
            CsrIndexE <= mstatus; // Reset CSR index
            JumpE <= 'b0;
            JalrE <= 'b0;
            CsrOperationE <= csrrw; // Reset CSR operation
            CsrAccessE <= 0; // Reset CSR access
            PCPlus4E <= 'b0;
            MRetE <= 0;
            EcallE <= 0;
            EbreakE <= 0;
            IllegaleInstructionE <= 0;
            RdFE <= f0;
            RD1FE <= 'b0;
            RD2FE <= 'b0;
            FPUControlE <= NOOPERATION;
            RoundModeE <= RNE;
            MoveOperationE <= FPUToFPU;
            FPURegWriteE <= 1'b0;
            Rs1FE <= f0;
            Rs2FE <= f0;
            FPUValidE <= 1'b0;
        end
        else if(!StallE)
        begin
            ValidE <= ValidD;
            Rs1E <= Rs1D;
            Rs2E <= Rs2D;
            RdE <= RdD;
            ALUControlE <= ALUControlD;
            RD1E <= RD1D;
            RD2E <= RD2D;
            SignImmE <= SignImmD;
            PCBranchE <= PCBranchD;
            funct3E <= funct3D;
            RegWriteE <= RegWriteD;
            SelectorE <= SelectorD;
            MemWriteE <= MemWriteD;
            MemReadE <= MemReadD;
            BranchE <= BranchD;
            ALUSrcE <= ALUSrcD;
            AuipcE <= AuipcD;
            WordOpE <= WordOpD;
            JumpE <= JumpD;
            JalrE <= JalrD;
            CsrOperationE <= CsrOperationD; // Pass CSR operation to the next stage
            CsrAccessE <= CsrAccessD; // Pass CSR access to the next stage
            CsrIndexE <= CsrIndexD; // Pass CSR index to the next stage
            PCPlus4E <= PCPlus4D;
            MRetE <= MRetD;
            EcallE <= EcallD;
            EbreakE <= EbreakD;
            IllegaleInstructionE <= IllegaleInstructionD || SystemIllegalD || CsrReadOnlyWriteD;
            RdFE <= RdFD;
            RD1FE <= RD1FD;
            RD2FE <= RD2FD;
            FPUControlE <= FPUControlD;
            RoundModeE <= RoundModeD;
            MoveOperationE <= MoveOperationD;
            FPURegWriteE <= FPURegWriteD;
            Rs1FE <= Rs1FD;
            Rs2FE <= Rs2FD;
            FPUValidE <= FPUValidD;
        end
    end
    
    
    // Register fields. rs1/rs2 read as x0 when the format has no such field
    // (the bits belong to an immediate), so no false forwarding or stall can
    // come from them. FPR indices are always the raw fields.
    always_comb
    begin
        Rs1D = gpr_t'(InstructionD[19:15]);
        Rs2D = gpr_t'(InstructionD[24:20]);
        RdD  = gpr_t'(InstructionD[11:7]);
        if((opcodeD == LUI) || (opcodeD == AUIPC) || (opcodeD == JAL))
            Rs1D = zero;
        if(!((opcodeD == R_TYPE) || (opcodeD == OP_32) || (opcodeD == S_TYPE) || (opcodeD == B_TYPE)))
            Rs2D = zero;

        Rs1FD = fpr_t'(InstructionD[19:15]);
        Rs2FD = fpr_t'(InstructionD[24:20]);
        RdFD  = fpr_t'(InstructionD[11:7]);
    end


    // Immediates per format, sign-extended to XLEN
    always_comb
    begin
        SignImmD = '0;
        if(ImmediateD)
            SignImmD = {{(DATA_WIDTH-12){InstructionD[31]}}, InstructionD[31:20]};
        else if(UpperD)
            SignImmD = {{(DATA_WIDTH-32){InstructionD[31]}}, InstructionD[31:12], 12'b0};
        else if(BranchD)
            SignImmD = {{(DATA_WIDTH-13){InstructionD[31]}}, InstructionD[31], InstructionD[7], InstructionD[30:25], InstructionD[11:8], 1'b0};
        else if(StoreD)
            SignImmD = {{(DATA_WIDTH-12){InstructionD[31]}}, InstructionD[31:25], InstructionD[11:7]};
        else if(JumpD)
            SignImmD = {{(DATA_WIDTH-21){InstructionD[31]}}, InstructionD[31], InstructionD[19:12], InstructionD[20], InstructionD[30:21], 1'b0};
    end

    // PC-relative target: branches, JAL and AUIPC use PC + immediate
    always_comb
    begin
        PCD = PCPlus4D - DATA_WIDTH'(4);
        PCBranchD = PCD + SignImmD;
    end

    // Writing a read-only CSR (address bits [11:10] == 2'b11) is an illegal
    // instruction. CSRRW/CSRRWI always write; the set/clear forms write only
    // when rs1 / uimm is non-zero.
    always_comb
    begin
        CsrReadOnlyWriteD = CsrAccessD && (InstructionD[31:30] == 2'b11) &&
                            ((CsrOperationD == csrrw) || (CsrOperationD == csrrwi) ||
                             (InstructionD[19:15] != '0));
    end

    always_comb
    begin
        opcodeD = opcode_t'(InstructionD[6:0]);
        funct3D = InstructionD[14:12];
        funct7D = InstructionD[31:25];
        CsrOperationD = csr_t'(InstructionD[14:12]);
        CsrIndexD = csr_index_t'(InstructionD[31:20]); // Extract CSR index from instruction
        RoundModeD = round_mode_t'(InstructionD[14:12]);
    end

    // SYSTEM with funct3 = 000: ECALL, EBREAK, MRET and WFI (a legal NOP);
    // rs1 and rd must be zero, any other encoding is illegal.
    always_comb
    begin
        MRetD = 0;
        EcallD = 0;
        EbreakD = 0;
        SystemIllegalD = 0;
        if(MModeD)
        begin
            if(InstructionD[19:7] != '0)
                SystemIllegalD = 1;
            else if(InstructionD[31:20] == 12'b0011_0000_0010)
                MRetD = 1;
            else if(InstructionD[31:20] == 12'b0000_0000_0000)
                EcallD = 1;
            else if(InstructionD[31:20] == 12'b0000_0000_0001)
                EbreakD = 1;
            else if(InstructionD[31:20] != 12'b0001_0000_0101)    // WFI
                SystemIllegalD = 1;
        end
    end

endmodule
