// =============================================================================
// risc_control_unit.sv
// -----------------------------------------------------------------------------
// Control unit for RISC-V processor decode stage.
//
// Responsibilities:
//   - Decode opcode to generate high-level control signals
//   - Decode funct3/funct7 fields to generate ALU operation
//   - Generate FPU operation and move control signals
//   - Combine integer and FPU register write enables
//   - Detect illegal instructions
//
// Instantiates:
//   - opcode_decoder: main opcode decoding
//   - alu_decoder: ALU function decoding
//   - fpu_decoder: FPU instruction decoding
// =============================================================================
import shared_pkg::*;   

module risc_control_unit 
#(
    parameter int ALU_SUB_CONTROL_WIDTH = 2,
    parameter int DATA_WIDTH = 32               // XLEN
)
(
    // ─── Instruction fields ───────────────────────────────────────────────────
    input opcode_t opcode,           // Opcode field (bits 6:0)
    input [2:0] funct3,             // Function field 3 (bits 14:12)
    input [6:0] funct7,            // Function field 7 (bits 31:25)
    input csr_t CsrOperationD,      // CSR operation type
    input gpr_t Rs2,               // Source register 2 index

    // ─── Control signal outputs ───────────────────────────────────────────────
    output alu_operation_t ALUControlD,  // ALU operation select
    output logic RegWriteD,              // Combined register write enable
    output selector_t SelectorD,        // Write-back data select
    output logic MemWriteD,             // Memory write enable
    output logic MemReadD,              // Memory read enable
    output logic BranchD,               // Branch instruction flag
    output logic ImmediateD,            // I-type immediate present flag
    output logic UpperD,                // U-type immediate present flag
    output logic AuipcD,                // Operand A is the PC
    output logic ALUSrcD,               // ALU operand B select
    output logic StoreD,                // Store instruction flag
    output logic CsrAccessD,            // CSR access enable
    output logic MModeD,                // Machine mode enable
    output logic JumpD,                 // Jump instruction flag
    output logic JalrD,                 // Jump target from rs1 (JALR)
    output logic WordOpD,               // RV64 32-bit operation
    output logic IllegaleInstructionD,  // Illegal instruction flag

    // ─── FPU control outputs ──────────────────────────────────────────────────
    output fpu_operation_t FPUControlD,   // FPU operation type
    output move_operation_t MoveOperationD, // FPU move operation
    output logic FPURegWriteD,            // FPR write enable
    output logic FPUValidD               // Valid FPU operation
);

    // ─── Internal wires – control signals ─────────────────────────────────────
    logic [ALU_SUB_CONTROL_WIDTH-1:0] ALUControl;  // ALU control from decoder
    logic WriteFromFPU, RegWrite;                  // FPU and integer write enables
    logic FPUD;                                    // FPU instruction flag
    logic OpcodeIllegal;                           // Illegal opcode / funct3
    logic ALUIllegal;                              // Illegal funct3 / funct7 for the ALU
    logic UsesALUDecoder;                          // R-type, I-type, OP-32, OP-IMM-32

    // ─── Combined register write enable ───────────────────────────────────────
    always_comb
    begin
        RegWriteD = RegWrite | WriteFromFPU;    // OR integer and FPU write enables
    end

    // ─── Combined illegal-instruction detection ───────────────────────────────
    always_comb
    begin
        UsesALUDecoder = (opcode == R_TYPE) || (opcode == I_TYPE) ||
                         (opcode == OP_32)  || (opcode == OP_IMM_32);
        IllegaleInstructionD = OpcodeIllegal || (UsesALUDecoder && ALUIllegal) ||
                               (FPUD && !FPUValidD);
    end

    // ─── risc_control_unit: opcode decoder ────────────────────────────────────
    opcode_decoder #(.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH),.DATA_WIDTH(DATA_WIDTH)) opdec(
        .opcode(opcode),
        .funct3(funct3),
        .ALUControl(ALUControl),
        .Jump(JumpD),
        .Jalr(JalrD),
        .Branch(BranchD),
        .Immediate(ImmediateD),
        .Upper(UpperD),
        .Auipc(AuipcD),
        .CsrOperation(CsrOperationD),
        .MemWrite(MemWriteD),
        .MemRead(MemReadD),
        .Selector(SelectorD),
        .ALUSrc(ALUSrcD),
        .Store(StoreD),
        .RegWrite(RegWrite),
        .WordOp(WordOpD),
        .CsrAccess(CsrAccessD),
        .MMode(MModeD),
        .FPU(FPUD),
        .IllegaleInstruction(OpcodeIllegal)
    );
    

    alu_decoder #(.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH),.DATA_WIDTH(DATA_WIDTH)) aludec(
        .funct3(funct3),
        .funct7(funct7),
        .ALUControl(ALUControl),
        .WordOp(WordOpD),
        .ALUControlD(ALUControlD),
        .Illegal(ALUIllegal)
    );

    fpu_decoder fpudec(
        .funct3(funct3),
        .funct7(funct7),
        .Rs2(Rs2),
        .FPUD(FPUD), 
        .FPUControlD(FPUControlD),
        .MoveOperationD(MoveOperationD),
        .FPURegWriteD(FPURegWriteD),
        .Write(WriteFromFPU),
        .FPUValidD(FPUValidD)
    );


endmodule
