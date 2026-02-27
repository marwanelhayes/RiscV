import shared_pkg::*;

module riscv_processor
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 8,
    parameter int ALU_SUB_CONTROL_WIDTH = 2
)
(
    input clk,
    input rst,
    input ExternalInterrupt,
    input TimerInterrupt,
    input SoftwareInterrupt
);

    //Fetch stage wires
    wire [ADDR_WIDTH-1:0] PCF;
    wire [ADDR_WIDTH-1:0] PCPlus4F;

    //Decode stage wires
    wire [ADDR_WIDTH-1:0] PCPlus4D;
    wire [DATA_WIDTH-1:0] InstructionD;
    wire StallD;
    wire FlushD;
    gpr_t Rs1D;
    gpr_t Rs2D;

    //Execute stage wires
    wire signed [DATA_WIDTH-1:0] RD1E;
    wire signed [DATA_WIDTH-1:0] RD2E;
    wire signed [DATA_WIDTH-1:0] SignImmE;
    wire [ADDR_WIDTH-1:0] PCBranchE;
    wire [ADDR_WIDTH-1:0] PCPlus4E;
    wire JumpE;
    wire ALUSrcE;
    wire [1:0] ForwardAE;
    wire [1:0] ForwardBE;
    wire FlushE;
    wire RegWriteE;
    selector_t SelectorE;
    wire MemWriteE;
    gpr_t Rs1E;
    gpr_t Rs2E;
    gpr_t RdE;
    alu_operation_t ALUControlE;
    wire BranchE;
    wire [2:0] funct3E;
    wire PCSrcE;
    wire CsrAccessE;
    csr_t CsrOperationE;
    csr_index_t CsrIndexE;
    wire IllegaleInstructionE;
    wire MRetE;
    wire EcallE;
    wire EbreakE;
    fpr_t RdFE;
    wire [DATA_WIDTH-1:0] RD1FE;
    wire [DATA_WIDTH-1:0] RD2FE;
    fpu_operation_t FPUControlE;
    round_mode_t RoundModeE;
    wire FPURegWriteE;
    move_operation_t MoveOperationE;
    fpr_t Rs1FE;
    fpr_t Rs2FE;
    wire [1:0] ForwardFloatingAE;
    wire [1:0] ForwardFloatingBE;


    //Memory stage wires
    wire signed [DATA_WIDTH-1:0] ALUOutM;
    wire signed [DATA_WIDTH-1:0] WriteDataM;
    wire [2:0] funct3M;
    gpr_t RdM;
    wire RegWriteM;
    wire [DATA_WIDTH-1:0] CsrOutM;
    selector_t SelectorM;
    wire MemWriteM;
    wire [ADDR_WIDTH-1:0] PCPlus4M;
    fpr_t RdFM;
    wire OverflowM;
    wire UnderflowM;
    wire NaNM;
    wire InfM;
    wire ZeroM;
    wire InvalidDivM;
    wire [DATA_WIDTH-1:0] FPUOutM;
    wire FPURegWriteM;
    move_operation_t MoveOperationM;

    //Write back stage wires
    wire signed [DATA_WIDTH-1:0] ReadDataW;
    wire signed [DATA_WIDTH-1:0] ALUOutW;
    wire signed [DATA_WIDTH-1:0] ResultW;
    wire [DATA_WIDTH-1:0] CsrOutW;
    gpr_t RdW;
    selector_t SelectorW;
    wire RegWriteW;
    wire [ADDR_WIDTH-1:0] PCPlus4W;
    fpr_t RdFW;
    wire [DATA_WIDTH-1:0] FPUOutW;
    move_operation_t MoveOperationW;
    wire FPURegWriteW;

    //Traps
    wire TrapIsSet;
    wire [ADDR_WIDTH-1:0] CsrOutPC;

    fetch_stage #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) 
    Fetch
    (
        .clk(clk),
        .rst(rst),
        .PCF(PCF),
        .FlushD(FlushD),
        .StallD(StallD),
        .PCPlus4D(PCPlus4D),
        .InstructionD(InstructionD),
        .PCPlus4F(PCPlus4F)
    );

    decode_stage #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH)) 
    Decode
    (
        .clk(clk),
        .rst(rst),
        .PCPlus4D(PCPlus4D),
        .InstructionD(InstructionD),
        .FlushE(FlushE),
        .RegWriteW(RegWriteW),
        .RdW(RdW),
        .BranchE(BranchE),
        .funct3E(funct3E),
        .ResultW(ResultW),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .RdE(RdE),
        .ALUControlE(ALUControlE),
        .RD1E(RD1E),
        .RD2E(RD2E),
        .CsrIndexE(CsrIndexE),
        .SignImmE(SignImmE),
        .RegWriteE(RegWriteE),
        .SelectorE(SelectorE),
        .MemWriteE(MemWriteE),
        .PCBranchE(PCBranchE),
        .PCPlus4E(PCPlus4E),
        .JumpE(JumpE),
        .CsrOperationE(CsrOperationE),
        .CsrAccessE(CsrAccessE),
        .ALUSrcE(ALUSrcE),
        .MRetE(MRetE),
        .EcallE(EcallE),
        .EbreakE(EbreakE),
        .IllegaleInstructionE(IllegaleInstructionE),
        .RdFW(RdFW),
        .FPUOutW(FPUOutW),
        .MoveOperationW(MoveOperationW),
        .FPURegWriteW(FPURegWriteW),
        .RdFE(RdFE),
        .RD1FE(RD1FE),
        .RD2FE(RD2FE),
        .FPUControlE(FPUControlE),
        .RoundModeE(RoundModeE),
        .FPURegWriteE(FPURegWriteE),
        .MoveOperationE(MoveOperationE),
        .Rs1FE(Rs1FE),
        .Rs2FE(Rs2FE)
    );

    execute_stage #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.ALU_SUB_CONTROL_WIDTH(ALU_SUB_CONTROL_WIDTH)) 
    Execute
    (
        .clk(clk),
        .rst(rst),
        .RD1E(RD1E),
        .RD2E(RD2E),
        .SignImmE(SignImmE),
        .ResultW(ResultW),
        .ALUControlE(ALUControlE),
        .funct3E(funct3E),
        .BranchE(BranchE),
        .PCPlus4E(PCPlus4E),
        .PCSrcE(PCSrcE),
        .JumpE(JumpE),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .Rs1E(Rs1E),
        .RdE(RdE),
        .ALUSrcE(ALUSrcE),
        .CsrAccessE(CsrAccessE),
        .MRetE(MRetE),
        .EcallE(EcallE),
        .EbreakE(EbreakE),
        .ExternalInterrupt(ExternalInterrupt),
        .TimerInterrupt(TimerInterrupt),
        .SoftwareInterrupt(SoftwareInterrupt),
        .CsrOutPC(CsrOutPC),
        .TrapIsSet(TrapIsSet),
        .IllegaleInstructionE(IllegaleInstructionE),
        .CsrOperationE(CsrOperationE),
        .funct3M(funct3M),
        .RegWriteE(RegWriteE),
        .CsrIndexE(CsrIndexE),
        .SelectorE(SelectorE),
        .MemWriteE(MemWriteE),
        .ALUOutM(ALUOutM),
        .WriteDataM(WriteDataM),
        .RdM(RdM),
        .PCPlus4M(PCPlus4M),
        .CsrOutM(CsrOutM),
        .RegWriteM(RegWriteM),
        .SelectorM(SelectorM),
        .MemWriteM(MemWriteM),
        .RdFE(RdFE),
        .RD1FE(RD1FE),
        .RD2FE(RD2FE),
        .FPUControlE(FPUControlE),
        .RoundModeE(RoundModeE),
        .MoveOperationE(MoveOperationE),
        .FPURegWriteE(FPURegWriteE),
        .RdFM(RdFM),
        .OverflowM(OverflowM),
        .UnderflowM(UnderflowM),
        .NaNM(NaNM),
        .InfM(InfM),
        .ZeroM(ZeroM),
        .InvalidDivM(InvalidDivM),
        .FPUOutM(FPUOutM),
        .FPURegWriteM(FPURegWriteM),
        .MoveOperationM(MoveOperationM),
        .Rs1FE(Rs1FE),
        .Rs2FE(Rs2FE),
        .ForwardFloatingAE(ForwardFloatingAE),
        .ForwardFloatingBE(ForwardFloatingBE)
    );

    memory_stage #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) 
    Memory
    (
        .clk(clk),
        .rst(rst),
        .ALUOutM(ALUOutM),
        .funct3M(funct3M),
        .WriteDataM(WriteDataM),
        .RdM(RdM),
        .CsrOutM(CsrOutM),
        .PCPlus4M(PCPlus4M),
        .RegWriteW(RegWriteW),
        .RegWriteM(RegWriteM),
        .SelectorM(SelectorM),
        .MemWriteM(MemWriteM),
        .ReadDataW(ReadDataW),
        .RdW(RdW),
        .PCPlus4W(PCPlus4W),
        .SelectorW(SelectorW),
        .CsrOutW(CsrOutW),
        .ALUOutW(ALUOutW),
        .RdFM(RdFM),
        .OverflowM(OverflowM),
        .UnderflowM(UnderflowM),
        .NaNM(NaNM),
        .InfM(InfM),
        .ZeroM(ZeroM),
        .InvalidDivM(InvalidDivM),
        .FPUOutM(FPUOutM),
        .FPURegWriteM(FPURegWriteM),
        .MoveOperationM(MoveOperationM),
        .RdFW(RdFW),
        .OverflowW(OverflowW),
        .UnderflowW(UnderflowW),
        .NaNW(NaNW),
        .InfW(InfW),
        .ZeroW(ZeroW),
        .InvalidDivW(InvalidDivW),
        .FPUOutW(FPUOutW),
        .FPURegWriteW(FPURegWriteW),
        .MoveOperationW(MoveOperationW)
    );

    wb_stage #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) 
    WriteBack
    (
        .clk(clk),
        .rst(rst),
        .PCSrcE(PCSrcE),
        .StallF(StallF),
        .PCPlus4W(PCPlus4W),
        .PCPlus4F(PCPlus4F),
        .CsrOutW(CsrOutW),
        .PCBranchE(PCBranchE),
        .ALUOutW(ALUOutW),
        .ReadDataW(ReadDataW),
        .CsrOutPC(CsrOutPC),
        .TrapIsSet(TrapIsSet),
        .SelectorW(SelectorW),
        .ResultW(ResultW),
        .PCF(PCF) 
    );

    hazard_unit Hazard
    (
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .Rs1D(Rs1D), 
        .Rs2D(Rs2D), 
        .RdM(RdM),
        .RdW(RdW),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),
        .PCSrcE(PCSrcE),
        .TrapIsSet(TrapIsSet),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .StallD(StallD),
        .StallF(StallF),
        .FlushE(FlushE),
        .SelectorE(SelectorE),
        .FlushD(FlushD),
        .ForwardFloatingAE(ForwardFloatingAE),
        .ForwardFloatingBE(ForwardFloatingBE),
        .MoveOperationE(MoveOperationE),
        .RdFM(RdFM),
        .RdFW(RdFW),
        .Rs1FE(Rs1FE),
        .Rs2FE(Rs2FE),
        .FPURegWriteM(FPURegWriteM),
        .FPURegWriteW(FPURegWriteW)
    );

endmodule