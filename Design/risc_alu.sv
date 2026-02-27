import shared_pkg::*;
module risc_alu 
#(
    parameter int DATA_WIDTH = 32
) 
(
    input signed [DATA_WIDTH-1:0] SrcA,SrcB,
    input alu_operation_t alu_control,
    input branch_t alu_branch_control,
    output logic branch_true,
    output logic signed [DATA_WIDTH:0] Y
);

    logic signed [2*DATA_WIDTH - 1:0] MulOutput;
    logic signed [DATA_WIDTH-1:0] DivOutput;
    logic signed [DATA_WIDTH-1:0] RemOutput;
    mul_sel_t mul_sel;
    logic Divsign;

    always_comb 
    begin
        if((alu_control == MUL) || (alu_control == MULH))
            mul_sel = sign;
        else if((alu_control == MULHU))
            mul_sel = unsign;
        else if((alu_control == MULHSU))
            mul_sel = signXunsign;
        else
            mul_sel = error;
    end

    always_comb 
    begin
        if((alu_control == REM) || (alu_control == DIV))
            Divsign = 1;
        else
            Divsign = 0;
    end

    wallace_tree #(.WIDTH(DATA_WIDTH)) mul (
        .A(SrcA),
        .B(SrcB),
        .sel(mul_sel),
        .P(MulOutput)
    );

    non_restoring_divider #(.WIDTH(DATA_WIDTH)) div (
        .dividend(SrcA),
        .divisor(SrcB),
        .sign(Divsign),
        .quotient(DivOutput),
        .remainder(RemOutput)
    );






    always_comb 
    begin
        Y = 0;
        case(alu_control)
            ADD     :   Y = $signed(SrcA) + $signed(SrcB); 
            SUB     :   Y = $signed(SrcA) - $signed(SrcB);
            AND     :   Y = SrcA & SrcB;
            OR      :   Y = SrcA | SrcB;
            XOR     :   Y = SrcA ^ SrcB;
            SLT     :   begin
                            if($signed(SrcA) < $signed(SrcB))
                                Y[0] = 1;
                            else
                                Y[0] = 0;
                        end
            SLTU    :   begin
                            if($unsigned(SrcA) < $unsigned(SrcB))
                                Y[0] = 1;
                            else
                                Y[0] = 0;
                        end
            SLL     :   Y = SrcA << SrcB;
            SRL     :   Y = SrcA >> SrcB;
            SRA     :   Y = SrcA >>> SrcB;
            MUL     :   Y = MulOutput[DATA_WIDTH-1:0];
            MULH    :   Y = MulOutput[2*DATA_WIDTH-1:DATA_WIDTH];
            MULHSU  :   Y = MulOutput[2*DATA_WIDTH-1:DATA_WIDTH];
            MULHU   :   Y = $unsigned(MulOutput[2*DATA_WIDTH-1:DATA_WIDTH]);
            DIV     :   Y = DivOutput;
            REM     :   Y = RemOutput;
            DIVU    :   Y = $unsigned(DivOutput);
            REMU    :   Y = $unsigned(RemOutput);
        endcase 
    end

    always_comb 
    begin
        branch_true = 0;
        case(alu_branch_control)
            BEQ     :   begin
                            branch_true = !Y;
                        end
            BNE     :   begin
                            branch_true = |Y;
                        end
            BLT     :   begin
                            branch_true = Y[DATA_WIDTH];
                        end
            BGE     :   begin
                            branch_true = !Y[DATA_WIDTH];
                        end
            BLTU    :   begin
                            branch_true = Y[0];
                        end
            BGEU    :   begin
                            branch_true = !Y[0];
                        end
        endcase
    end

    


endmodule
