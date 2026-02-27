module data_memory
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] a1,
    input signed [DATA_WIDTH-1:0] Wdata,
    input we,
    output logic signed [DATA_WIDTH-1:0] RDdata
);
    localparam DEPTH = 2**ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    /*
    always_ff @(negedge clk or negedge rst) 
    begin
        if (!rst) 
        begin
            RDdata <= 0;
        end
        else 
        begin
            if(!we)
            begin
                RDdata <= mem[a1];
            end
        end
    end
    */

    assign RDdata = mem[a1];

    always_ff @(negedge clk or negedge rst) 
    begin
        if (!rst) 
        begin
            foreach(mem[i])
                mem[i] <= 0;
        end
        else 
        begin
            if(we)
            begin
                mem[a1] <= Wdata;
            end
        end
    end
endmodule
