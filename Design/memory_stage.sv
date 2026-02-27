import shared_pkg::*;
module memory_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] ALUOutM,
    input signed [DATA_WIDTH-1:0] WriteDataM,
    input [ADDR_WIDTH-1:0] PCPlus4M,
    input gpr_t RdM,
    input logic [2:0] funct3M,
    input RegWriteM,
    input logic [DATA_WIDTH-1:0] CsrOutM,
    input selector_t SelectorM,
    input MemWriteM,
    input fpr_t RdFM,
    input logic OverflowM,
    input logic UnderflowM,
    input logic NaNM,
    input logic InfM,
    input logic ZeroM,
    input logic InvalidDivM,
    input logic [DATA_WIDTH-1:0] FPUOutM,
    input move_operation_t MoveOperationM,
    input FPURegWriteM,
    
    output logic signed [DATA_WIDTH-1:0] ReadDataW,
    output gpr_t RdW,
    output logic RegWriteW,
    output selector_t SelectorW,
    output logic [ADDR_WIDTH-1:0] PCPlus4W,
    output logic [DATA_WIDTH-1:0] CsrOutW,
    output logic signed [DATA_WIDTH-1:0] ALUOutW,
    output fpr_t RdFW,
    output logic OverflowW,
    output logic UnderflowW,
    output logic NaNW,
    output logic InfW,    
    output logic ZeroW,
    output logic InvalidDivW,
    output logic [DATA_WIDTH-1:0] FPUOutW,
    output move_operation_t MoveOperationW,
    output logic FPURegWriteW
);

    logic [DATA_WIDTH-1:0] ReadDataM;

    risc_data_memory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) M1 
    (
        .clk(clk),
        .rst(rst),
        .a1(ALUOutM[ADDR_WIDTH-1:0]),
        .Wdata(WriteDataM),
        .we(MemWriteM),
        .sel(load_store_t'(funct3M)),
        .RDdata(ReadDataM)
    );


    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            ReadDataW <= 0;
            RegWriteW <= 0;
            SelectorW <= ALUToReg;
            RdW <= zero;
            ALUOutW <= 0;
            PCPlus4W <= 0;
            CsrOutW <= 0;
            RdFW <= f0;
            OverflowW <= 0;
            UnderflowW <= 0;
            NaNW <= 0;
            InfW <= 0;
            ZeroW <= 0;
            InvalidDivW <= 0;
            FPUOutW <= 0;
            MoveOperationW <= FPUToFPU;
            FPURegWriteW <= 0;
        end
        else
        begin
            ReadDataW <= ReadDataM;
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