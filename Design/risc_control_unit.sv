import shared_pkg::*;   
module risc_control_unit 
#(
    parameter int ALU_SUB_CONTROL_WIDTH = 2 
)
(
    input opcode_t opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input csr_t CsrOperationD,
    input gpr_t Rs2,
    output alu_operation_t ALUControlD,
    output logic RegWriteD,
    output selector_t SelectorD,
    output MemWriteD,
    output BranchD,
    output ImmediateD,
    output ALUSrcD,
    output StoreD,
    output CsrAccessD,
    output MModeD,
    output JumpD,
    output IllegaleInstructionD,
    output fpu_operation_t FPUControlD,
    output move_operation_t MoveOperationD,
    output FPURegWriteD
);



    wire [ALU_SUB_CONTROL_WIDTH-1:0] ALUControl;
    logic WriteFromFPU, RegWrite;
    wire FPUD;

    always_comb
    begin
        RegWriteD = RegWrite | WriteFromFPU;
    end

    opcode_decoder #(.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH)) opdec(
        .opcode(opcode),
        .ALUControl(ALUControl),
        .Jump(JumpD),
        .Branch(BranchD),
        .Immediate(ImmediateD),
        .CsrOperation(CsrOperationD),
        .MemWrite(MemWriteD),
        .Selector(SelectorD),
        .ALUSrc(ALUSrcD),
        .Store(StoreD),
        .RegWrite(RegWrite),
        .CsrAccess(CsrAccessD),
        .MMode(MModeD),
        .FPU(FPUD),
        .IllegaleInstruction(IllegaleInstructionD)
    );
    

    alu_decoder #(.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH)) aludec(
        .funct3(funct3),
        .funct7(funct7),
        .ALUControl(ALUControl),
        .ALUControlD(ALUControlD)
    );

    fpu_decoder fpudec(
        .funct3(funct3),
        .funct7(funct7),
        .Rs2(Rs2),
        .FPUD(FPUD), 
        .FPUControlD(FPUControlD),
        .MoveOperationD(MoveOperationD),
        .FPURegWriteD(FPURegWriteD),
        .Write(WriteFromFPU)
    );


endmodule