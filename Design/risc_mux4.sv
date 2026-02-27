module risc_mux4
#(
    parameter int DATA_WIDTH = 32
) 
(
    input [DATA_WIDTH-1:0] IN_1,IN_2,IN_3,IN_4,IN_5,IN_6,IN_7,IN_8,
    input [2:0] sel,
    output logic [DATA_WIDTH-1:0] Y
);

    always_comb 
    begin
        Y = 0;
        case(sel)
            3'b000   : Y = IN_1;
            3'b001   : Y = IN_2;
            3'b010   : Y = IN_3;
            3'b011   : Y = IN_4;
            3'b100   : Y = IN_5;
            3'b101   : Y = IN_6;
            3'b110   : Y = IN_7;
            3'b111   : Y = IN_8;
        endcase
    end
endmodule