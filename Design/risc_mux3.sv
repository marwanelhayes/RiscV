module risc_mux3
#(
    parameter int DATA_WIDTH = 32
) 
(
    input [DATA_WIDTH-1:0] IN_1,IN_2,IN_3,IN_4,
    input [1:0] sel,
    output logic [DATA_WIDTH-1:0] Y
);

    always_comb 
    begin
        Y = 0;
        case(sel)
            2'b00   : Y = IN_1;
            2'b01   : Y = IN_2;
            2'b10   : Y = IN_3;
            2'b11   : Y = IN_4;
        endcase
    end
endmodule