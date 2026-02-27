module pc_adder
#(
    parameter int ADDR_WIDTH = 32
) 
(
    input [ADDR_WIDTH-1:0] PC,
    output logic [ADDR_WIDTH-1:0] PCPlus4
);
    always_comb
    begin
        PCPlus4 = PC + 4;
    end
endmodule