import shared_pkg::*;
module risc_mem
#(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 5
) 
(
    input clk,
    input rst,
    input gpr_t Rs1,Rs2,Rd,
    input signed [DATA_WIDTH-1:0] WData,
    input WE,
    output logic signed [DATA_WIDTH-1:0] RD1,RD2
);
    localparam int DEPTH = 2**ADDR_WIDTH;
    
    logic [DATA_WIDTH-1:0] mem [32];


    assign RD1 = mem[Rs1];
    assign RD2 = mem[Rs2];


    always_ff @(negedge clk or negedge rst) 
    begin
        if (!rst) 
        begin
            foreach(mem[i]) 
                mem[i] <= 0;
        end
        else if (WE) 
        begin
            mem[Rd] <= WData;
        end
    end

endmodule   