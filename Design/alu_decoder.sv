import shared_pkg::*;
module alu_decoder
#(
    parameter int ALU_SUB_CONTROL_WIDTH = 2
)
(
    input [2:0] funct3,
    input [6:0] funct7,
    input [ALU_SUB_CONTROL_WIDTH-1:0] ALUControl,
    output alu_operation_t ALUControlD
);

    logic Unsign;

    always_comb
    begin
        Unsign = funct3[2] & funct3[1];
    end

    always_comb
    begin
        ALUControlD = ADD;
        case(ALUControl)
            2'b00: begin
                        if(Unsign)
                        begin
                            ALUControlD = SLTU;
                        end
                        else
                        begin
                            ALUControlD = SUB;
                        end
                    end
            2'b01: begin
                        case(funct3)
                            3'b000: ALUControlD = ADD;
                            3'b010: ALUControlD = SLT;
                            3'b011: ALUControlD = SLTU;
                            3'b100: ALUControlD = XOR;
                            3'b110: ALUControlD = OR;
                            3'b111: ALUControlD = AND;
                        endcase
                    end
            2'b10: begin
                        if(!(|funct7))
                        begin
                            case(funct3)
                                3'b000: ALUControlD = ADD;
                                3'b001: ALUControlD = SLL;
                                3'b010: ALUControlD = SLT;
                                3'b011: ALUControlD = SLTU;
                                3'b100: ALUControlD = XOR;
                                3'b101: ALUControlD = SRL;
                                3'b110: ALUControlD = OR;
                                3'b111: ALUControlD = AND;
                            endcase
                        end
                        else if(funct7[5])
                        begin
                            case(funct3)
                                3'b000: ALUControlD = SUB;
                                3'b101: ALUControlD = SRA;
                            endcase
                        end
                        else if(funct7[0]) //M extension
                        begin
                            case(funct3)
                                3'b000: ALUControlD = MUL;
                                3'b001: ALUControlD = MULH;
                                3'b010: ALUControlD = MULHSU;
                                3'b011: ALUControlD = MULHU;
                                3'b100: ALUControlD = DIV;
                                3'b101: ALUControlD = DIVU;
                                3'b110: ALUControlD = REM;
                                3'b111: ALUControlD = REMU;
                            endcase
                        end
                    end
            default: ALUControlD = ADD;
        endcase
    end



endmodule
