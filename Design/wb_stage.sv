import shared_pkg::*;
module wb_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input clk,
    input rst,
    input PCSrcE,
    input StallF,
    input [ADDR_WIDTH-1:0] PCPlus4F,
    input [ADDR_WIDTH-1:0] PCBranchE,
    input [DATA_WIDTH-1:0] ALUOutW,
    input [DATA_WIDTH-1:0] ReadDataW,
    input selector_t SelectorW,
    input logic [ADDR_WIDTH-1:0] CsrOutPC,
    input logic TrapIsSet,
    input [ADDR_WIDTH-1:0] PCPlus4W,
    input [DATA_WIDTH-1:0] CsrOutW,
    output logic [DATA_WIDTH-1:0] ResultW,
    output logic [ADDR_WIDTH-1:0] PCF
);

    wire [ADDR_WIDTH-1:0] PCW;

    risc_mux2 #(.DATA_WIDTH(ADDR_WIDTH)) M2
    (
        .IN_1(PCPlus4F),
        .IN_2(PCBranchE),
        .sel(PCSrcE),
        .Y(PCW)
    );

    always_comb
    begin
        ResultW = 'b0; // Default value
        case(SelectorW)
            ALUToReg: ResultW = ALUOutW;
            MemToReg: ResultW = ReadDataW;
            CSRToReg: ResultW = CsrOutW;
            PCToReg : ResultW = PCPlus4W;
        endcase
    end

    always_ff @(posedge clk or negedge rst) 
    begin
        if(!rst)
        begin
            PCF <= 0;
        end
        else if(TrapIsSet)
        begin
            PCF <= CsrOutPC;
        end
        else if(!StallF)
        begin
            PCF <= PCW;
        end
    end
endmodule