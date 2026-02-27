module fetch_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] PCF,
    input StallD,
    input FlushD,
    output logic [ADDR_WIDTH-1:0] PCPlus4D,
    output logic [DATA_WIDTH-1:0] InstructionD,
    output wire [ADDR_WIDTH-1:0] PCPlus4F
);
    logic [DATA_WIDTH-1:0] InstructionF;

    pc_adder #(.ADDR_WIDTH(ADDR_WIDTH)) P1 
    (
        .PC(PCF),
        .PCPlus4(PCPlus4F)
    );

    risc_instruction_memory #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) IM1 
    (
        .a1(PCF[ADDR_WIDTH-1:2]),
        .RDdata(InstructionF)
    );

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            PCPlus4D <= 0;
            InstructionD <= 32'h00_00_00_33; // Default instruction (NOP)
        end
        else if(FlushD)
        begin
            PCPlus4D <= 0;
            InstructionD <= 32'h00_00_00_33; // Default instruction (NOP)
        end
        else if(!StallD)
        begin
            PCPlus4D <= PCPlus4F;
            InstructionD <= InstructionF;
        end
    end


endmodule