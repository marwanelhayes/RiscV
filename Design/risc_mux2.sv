module risc_mux2
#(
    parameter int DATA_WIDTH = 32
) 
(
    input [DATA_WIDTH-1:0] IN_1,IN_2,
    input sel,
    output logic [DATA_WIDTH-1:0] Y
);

    always_comb 
    begin
        if(sel)
        begin
            Y = IN_2;
        end
        else
        begin
            Y = IN_1;
        end
    end
endmodule