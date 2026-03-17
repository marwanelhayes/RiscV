import shared_pkg::*;
`define VERIF 1
module execute_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ALU_SUB_CONTROL_WIDTH = 2,
    parameter int STAGES = 4
)
(
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] RD1E,
    input signed [DATA_WIDTH-1:0] RD2E,
    input signed [DATA_WIDTH-1:0] SignImmE,
    input signed [DATA_WIDTH-1:0] ResultW,
    input [ADDR_WIDTH-1:0] PCPlus4E,
    input alu_operation_t ALUControlE,
    input logic [2:0] funct3E,
    input BranchE,
    input JumpE,
    input [2:0] ForwardAE,
    input [2:0] ForwardBE,
    input gpr_t Rs1E,
    input gpr_t RdE,
    input RegWriteE,
    input CsrAccessE,
    input csr_t CsrOperationE,
    input csr_index_t CsrIndexE,
    input selector_t SelectorE,
    input ALUSrcE,
    input MemWriteE,
    input MRetE,
    input EcallE,
    input EbreakE,
    input IllegaleInstructionE,
    input TimerInterrupt,
    input ExternalInterrupt,
    input SoftwareInterrupt,
    input fpr_t RdFE,
    input [DATA_WIDTH-1:0] RD1FE,
    input [DATA_WIDTH-1:0] RD2FE,
    input fpu_operation_t FPUControlE,
    input round_mode_t RoundModeE,
    input FPURegWriteE,
    input FPUValidE,
    input move_operation_t MoveOperationE,
    input logic [DATA_WIDTH-1:0] FPUOutW,
    input logic [1:0] ForwardFloatingAE,
    input logic [1:0] ForwardFloatingBE,
    input fpr_t Rs1FE,
    input fpr_t Rs2FE,

    output logic signed [DATA_WIDTH-1:0] ALUOutM,
    output logic signed [DATA_WIDTH-1:0] WriteDataM,
    output gpr_t RdM,
    output logic PCSrcE,
    output logic RegWriteM,
    output logic [ADDR_WIDTH-1:0] PCPlus4M,
    output selector_t SelectorM,
    output logic [2:0] funct3M,
    output logic [DATA_WIDTH-1:0] CsrOutM,
    output logic MemWriteM,
    output logic TrapIsSet,
    output logic [ADDR_WIDTH-1:0] CsrOutPC,
    output fpr_t RdFM,
    output logic OverflowM,
    output logic UnderflowM,
    output logic NaNM,
    output logic InfM,
    output logic ZeroM,
    output logic InvalidDivM,
    output logic [DATA_WIDTH-1:0] FPUOutM,
    output logic FPURegWriteM,
    output move_operation_t MoveOperationM,
    output logic FPUBusyM,
    output logic FPUDoneM
);

    logic signed [DATA_WIDTH:0] ALUOutE;
    logic signed [DATA_WIDTH-1:0] SrcAE;
    logic signed [DATA_WIDTH-1:0] SrcBE;
    logic signed [DATA_WIDTH-1:0] WriteDataE;
    logic branch_true;
    traps_t TrapsE;
    logic [DATA_WIDTH-1:0] FPUInAE,FPUInBE, FPUInAETemp;
    round_mode_t DynRoundMode,ActualRoundMode;

    risc_alu #(.DATA_WIDTH(DATA_WIDTH)) ALU
    (
        .SrcA(SrcAE),
        .SrcB(SrcBE),
        .alu_branch_control(branch_t'(funct3E)),
        .alu_control(ALUControlE),
        .Y(ALUOutE),
        .branch_true(branch_true)
    );

    risc_fpu #(.PRECISION(SINGLE),.STAGES(STAGES)) FPU
    (
        .clk(clk),
        .rst(rst),
        .valid(FPUValidE),
        .InA(FPUInAE),
        .InB(FPUInBE),
        .round_mode(ActualRoundMode),
        .operation(FPUControlE),
        .Overflow(OverflowM),
        .Underflow(UnderflowM),
        .RdF(RdFE),
        .NaN(NaNM),
        .Inf(InfM),
        .Zero(ZeroM),
        .InvalidDiv(InvalidDivM),
        .Result(FPUOutM),
        .busy(FPUBusyM),
        .done(FPUDoneM),
        .RdFOut(RdFM),
        .RegWriteOut(FPURegWriteM),
        .RegWrite(FPURegWriteE),
        .MoveOperation(MoveOperationE),
        .MoveOperationOut(MoveOperationM)
    );


    risc_mux4 #(.DATA_WIDTH(DATA_WIDTH)) M1 
    (
        .IN_1(RD1E),
        .IN_2(ResultW),
        .IN_3(ALUOutM),
        .IN_4(FPUOutW),
        .IN_5(FPUOutM),
        .IN_6(32'b0),
        .IN_7(32'b0),
        .IN_8(32'b0),
        .sel(ForwardAE),
        .Y(SrcAE)
    );


    risc_mux4 #(.DATA_WIDTH(DATA_WIDTH)) M2 
    (
        .IN_1(RD2E),
        .IN_2(ResultW),
        .IN_3(ALUOutM),
        .IN_4(FPUOutW),
        .IN_5(FPUOutM),
        .IN_6(32'b0),
        .IN_7(32'b0),
        .IN_8(32'b0),
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

    risc_mux3 #(.DATA_WIDTH(DATA_WIDTH)) F1
    (
        .IN_1(RD1FE),
        .IN_2(FPUOutW),
        .IN_3(FPUOutM),
        .IN_4(32'b0),
        .sel(ForwardFloatingAE),
        .Y(FPUInAETemp)
    );

    risc_mux3 #(.DATA_WIDTH(DATA_WIDTH)) F2
    (
        .IN_1(RD2FE),
        .IN_2(FPUOutW),
        .IN_3(FPUOutM),
        .IN_4(32'b0),
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
        .PC(PCPlus4E),
        .Address($unsigned(ALUOutE[ADDR_WIDTH-1:0])),
        .CsrAccess(CsrAccessE),
        .ExternalInterrupt(ExternalInterrupt),
        .TimerInterrupt(TimerInterrupt),
        .SoftwareInterrupt(SoftwareInterrupt),
        .CsrIn($unsigned(RD1E)),
        .CsrIndex(CsrIndexE),
        .CsrOutPC(CsrOutPC),
        .CsrOut(CsrOutM),
        .TrapIsSet(TrapIsSet),
        .RoundingMode(DynRoundMode)
    );

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            RegWriteM <= 0;
            SelectorM <= ALUToReg;
            MemWriteM <= 0;
            ALUOutM <= 0;
            WriteDataM <= 0;
            RdM <= zero;
            funct3M <= 0;
            PCPlus4M <= 0;
        end
        else
        begin
            RegWriteM <= RegWriteE;
            SelectorM <= SelectorE;
            MemWriteM <= MemWriteE;
            ALUOutM <= ALUOutE[DATA_WIDTH-1:0];
            WriteDataM <= WriteDataE;
            RdM <= RdE;
            funct3M <= funct3E;
            PCPlus4M <= PCPlus4E;
        end
    end

    always_comb
    begin
        PCSrcE = (BranchE & branch_true) | JumpE;
    end


    always_comb
    begin
        if(|PCPlus4E[1:0])
        begin
            TrapsE = InstructionAddressMisalignedOrUserSoftwareInterrupt;
        end
        else if(EbreakE | EcallE | IllegaleInstructionE)
        begin
            TrapsE = IllegalInstructionOrHypervisorSoftwareInterrupt;
        end
        else if(SelectorE == MemToReg)
        begin
            if((load_store_t'(funct3E) == W) && (|ALUOutE[1:0]))
            begin
                TrapsE = LoadAddressMisalignedOrUserSoftwareInterrupt;
            end
            else if(((load_store_t'(funct3E) == HW) | (load_store_t'(funct3E) == HWU)) && (ALUOutE == 2'b11))
            begin
                TrapsE = LoadAddressMisalignedOrUserSoftwareInterrupt;
            end
        end
        else if(MemWriteE)
        begin
            if((load_store_t'(funct3E) == W) && (|ALUOutE[1:0]))
            begin
                TrapsE = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
            end
            else if((ALUOutE == 2'b11) && (load_store_t'(funct3E) == HW))
            begin
                TrapsE = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
            end
        end
    end

    always_comb
    begin
        FPUInAE = FPUInAETemp;
        if(MoveOperationE == RegToFPU)
            FPUInAE = SrcAE;
    end

    always_comb
    begin
        ActualRoundMode = RoundModeE;
        if(RoundModeE == DYN)
        begin
            ActualRoundMode = DynRoundMode;
        end
    end
    `ifdef VERIF
        bind FPU flp_wr FPU_bind
        (
            .*
        );
    `endif
endmodule