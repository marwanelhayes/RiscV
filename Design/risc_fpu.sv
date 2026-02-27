import shared_pkg::*;
module risc_fpu #(
    parameter flp_t PRECISION   = SINGLE
)(
    input  logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InA, InB,
    input  round_mode_t round_mode,
    input  fpu_operation_t operation,
    output logic Overflow, Underflow, NaN, Inf, Zero,InvalidDiv,
    output logic [ (PRECISION == SINGLE) ? 31 : 63 :0] Result
);

    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InAddSubA, InAddSubB;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InMulA, InMulB;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InDivA, InDivB;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InSqrt;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] ResultAddSub, ResultMul, ResultDiv, ResultSqrt;

    localparam int WIDTH        = (PRECISION == SINGLE) ? 32 : 64;
    localparam int EXP_BITS     = (PRECISION == SINGLE) ? 8  : 11;
    localparam int FRAC_BITS    = (PRECISION == SINGLE) ? 23 : 52;
    localparam int BIAS         = (PRECISION == SINGLE) ? 127: 1023;
    
    mode_t add_sub_mode;

    logic OverflowAddSub, UnderflowAddSub, NaNAddSub, InfAddSub, ZeroAddSub;
    logic OverflowMul, UnderflowMul, NaNMul, InfMul, ZeroMul;
    logic OverflowDiv, UnderflowDiv, NaNDiv, InfDiv, ZeroDiv;
    logic InfSqrt, NanSqrt, ZeroSqrt;
    logic Subnormal;

    function logic signed [WIDTH-1:0] FloatToInt 
    (
        input  logic [WIDTH-1:0] float_in,
        input  logic SignOrUnsign,
        input round_mode_t round
    );
        logic sign;
        logic [EXP_BITS-1:0]  exponent;
        logic [FRAC_BITS:0] mantissa; // Including hidden bit
        logic signed [EXP_BITS:0] exp_unbiased;
        logic [WIDTH-1:0] InternalResult;
        logic [EXP_BITS-1:0] shift_amount;
        logic signed [1:0] round_up;
        bit frac_not_zero;

        round_up = 0;
        sign     = float_in[WIDTH-1];
        exponent = float_in[WIDTH-2 -:EXP_BITS];
        mantissa = {1'b1, float_in[FRAC_BITS-1:0]}; // Append hidden bit
        frac_not_zero = |float_in[FRAC_BITS-1:0];
        FloatToInt = 0;

        exp_unbiased = exponent - BIAS;

        InternalResult = mantissa;

        case(round)
            RNE: round_up = (SignOrUnsign & sign) ? {1'b1, InternalResult[FRAC_BITS-1]} : {1'b0, InternalResult[FRAC_BITS-1]};
            RTZ: round_up = 2'b0;
            RDN: round_up = (SignOrUnsign & sign) ? 2'b11 : 2'b0;
            RUP: round_up = 2'b01;
            RMM: round_up = (SignOrUnsign & sign) ? 2'b11 : 2'b01;
        endcase

        
        if ((!exponent) || (exp_unbiased[FRAC_BITS])) 
        begin
            // Denormalized or zero
            FloatToInt = 32'd0;
        end 
        else if (exp_unbiased > FRAC_BITS) 
        begin
            // Overflow beyond mantissa width
            FloatToInt = mantissa << (exp_unbiased[EXP_BITS-1:0] - FRAC_BITS);
        end 
        else 
        begin
            // Shift mantissa according to exponent
            shift_amount = FRAC_BITS - exp_unbiased[EXP_BITS-1:0];
            FloatToInt = mantissa >> shift_amount;
        end
        FloatToInt += round_up;
        if(SignOrUnsign && sign)
            FloatToInt = -FloatToInt;
    endfunction

    function logic [WIDTH-1:0] IntToFloat
    (
        input  logic signed [WIDTH-1:0] int_in,
        input  logic SignOrUnsign,
        input  round_mode_t round
    );
        logic sign;
        logic [WIDTH-1:0] abs_val;
        logic [EXP_BITS-1:0] exponent;
        logic [FRAC_BITS:0] mantissa;
        logic signed [EXP_BITS:0] exp_unbiased;
        int msb_index;
        logic signed [1:0] round_up;
        logic [WIDTH-1:0] result;

        // Step 1: Extract sign and absolute value
        sign    = int_in[WIDTH-1];
        abs_val = sign ? -int_in : int_in;
        mantissa = 0;
        msb_index = 0;
        exponent = 0;

        // Step 2: Handle zero
        if (abs_val == 0) 
        begin
            IntToFloat = {sign, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
        end
        else 
        begin
            // Step 3: Find MSB position (normalization)
            for (int i = 0; (i < WIDTH); i++) 
            begin
                if(abs_val[i])
                begin
                    msb_index = i;
                end
            end
            // Step 4: Compute unbiased exponent
            
            //exp_unbiased = msb_index;

            // Step 5: Bias exponent
            exponent = msb_index + BIAS;

            // Step 6: Normalize mantissa (drop hidden bit)
            abs_val = (abs_val << (WIDTH - 1 - msb_index));
            mantissa = abs_val[WIDTH-2 -: FRAC_BITS];

            // Step 7: Rounding logic (similar to FloatToInt)
            round_up = 0;
            case(round)
                RNE: round_up = mantissa[0]; // round to nearest even
                RTZ: round_up = 0;
                RDN: round_up = (sign) ? 2'b11 : 2'b0;
                RUP: round_up = (!sign) ? 2'b01 : 2'b0;
                RMM: round_up = 2'b01;
            endcase

            mantissa = mantissa + round_up;
            if(mantissa == (1 << FRAC_BITS)) // Check for mantissa overflow (e.g., 1.111... + 0.000... = 10.000...)
            begin
                mantissa = 0;
                exponent ++;
            end
            // Step 8: Pack into IEEE-754 format
            IntToFloat = {sign & SignOrUnsign, exponent, mantissa[FRAC_BITS-1:0]};
            end
    endfunction: IntToFloat

    // Classification function that returns 4-bit encoded status
    // Bit 3: is_subnormal, Bit 2: is_nan, Bit 1: is_infinity, Bit 0: is_zero
    function automatic logic [3:0] classify_value(
        input logic [EXP_BITS-1:0] exp,
        input logic [FRAC_BITS-1:0] frac
    );
        logic [3:0] classification;
        classification[0] = (exp == 0) && (frac == 0);                              // is_zero
        classification[1] = (exp == {EXP_BITS{1'b1}}) && (frac == 0);              // is_infinity
        classification[2] = (exp == {EXP_BITS{1'b1}}) && (frac != 0);              // is_nan
        classification[3] = (exp == 0) && (frac != 0);                             // is_subnormal
        return classification;
    endfunction: classify_value

    always_comb
    begin
        InAddSubA   = '0;
        InAddSubB   = '0;
        InMulA      = '0;
        InMulB      = '0;
        InDivA      = '0;
        InDivB      = '0;
        InSqrt      = '0;
        Overflow    = 1'b0;
        Underflow   = 1'b0;
        NaN         = 1'b0;
        Inf         = 1'b0;
        Zero        = 1'b0;
        Result      = '0;
        Subnormal   = 1'b0;
        add_sub_mode = ADD_FLP;
        
        case(operation)
            FADD_S:
            begin
                InAddSubA       = InA;
                InAddSubB       = InB;
                add_sub_mode    = ADD_FLP;
                Overflow        = OverflowAddSub;
                Underflow       = UnderflowAddSub;
                NaN             = NaNAddSub;
                Inf             = InfAddSub;
                Zero            = ZeroAddSub;
                Result          = ResultAddSub;
            end
            FSUB_S:
            begin
                InAddSubA       = InA;
                InAddSubB       = InB;
                add_sub_mode    = SUB_FLP;
                Overflow        = OverflowAddSub;
                Underflow       = UnderflowAddSub;
                NaN             = NaNAddSub;
                Inf             = InfAddSub;
                Zero            = ZeroAddSub;
                Result          = ResultAddSub;
            end
            FMUL_S:
            begin
                InMulA          = InA;
                InMulB          = InB;
                Overflow        = OverflowMul;
                Underflow       = UnderflowMul;
                NaN             = NaNMul;
                Inf             = InfMul;
                Zero            = ZeroMul;
                Result          = ResultMul;
            end
            FDIV_S:
            begin
                InDivA          = InA;
                InDivB          = InB;
                Overflow        = OverflowDiv;
                Underflow       = UnderflowDiv;
                NaN             = NaNDiv;
                Inf             = InfDiv;
                Zero            = ZeroDiv;
                Result          = ResultDiv;
            end
            FSQRT_S:
            begin
                Overflow        = 1'b0;
                Underflow       = 1'b0;
                InSqrt          = InA;
                NaN             = NanSqrt;
                Inf             = InfSqrt;
                Zero            = ZeroSqrt;
                Result          = ResultSqrt;
            end
            FSGNJ_S:
            begin
                Result = {InB[(PRECISION == SINGLE) ? 31 : 63], InA[(PRECISION == SINGLE) ? 30 : 62 :0]};
            end
            FSGNJN_S:
            begin
                Result = {~InB[(PRECISION == SINGLE) ? 31 : 63], InA[(PRECISION == SINGLE) ? 30 : 62 :0]};
            end
            FSGNJX_S:
            begin
                Result = {InA[(PRECISION == SINGLE) ? 31 : 63] ^ InB[(PRECISION == SINGLE) ? 31 : 63], InA[(PRECISION == SINGLE) ? 30 : 62 :0]};
            end
            FMIN_S:
            begin
                add_sub_mode    = SUB_FLP;
                InAddSubA = InA;
                InAddSubB = InB;
                if((ResultAddSub[(PRECISION == SINGLE) ? 31 : 63] == 1'b1) && (NaNAddSub == 1'b0))
                    Result = InA;
                else
                    Result = InB;
            end
            FMAX_S:
            begin
                add_sub_mode    = SUB_FLP;
                InAddSubA = InA;
                InAddSubB = InB;
                if(ResultAddSub[(PRECISION == SINGLE) ? 31 : 63] == 1'b0 && NaNAddSub == 1'b0)
                    Result = InA;
                else
                    Result = InB;
            end
            FCVT_W_S:
            begin
                Result = FloatToInt(InA, 1'b1, round_mode);
            end
            FCVT_WU_S:
            begin
                Result = FloatToInt(InA, 1'b0, round_mode);
            end
            FMV_X_S:
            begin
                Result = InA;
            end
            FEQ_S:
            begin
                add_sub_mode    = SUB_FLP;
                InAddSubA = InA;
                InAddSubB = InB;
                if(ZeroAddSub == 1'b1 && NaNAddSub == 1'b0)
                    Result = 32'd1;
                else
                    Result = 32'd0;
            end
            FLT_S:
            begin
                add_sub_mode    = SUB_FLP;
                InAddSubA = InA;
                InAddSubB = InB;
                if((!NaNAddSub) && (ResultAddSub[(PRECISION == SINGLE) ? 31 : 63] == 1'b1) && (!ZeroAddSub))
                    Result = 32'd1;
                else
                    Result = 32'd0;
            end
            FLE_S:
            begin
                add_sub_mode    = SUB_FLP;
                InAddSubA = InA;
                InAddSubB = InB;
                if(((ResultAddSub[(PRECISION == SINGLE) ? 31 : 63]) && (!NaNAddSub)) || (ZeroAddSub))
                    Result = 32'd1;
                else
                    Result = 32'd0;
            end
            FCLASS_S:
            begin
                //{Subnormal, NaN, Inf, Zero} = classify_value(InA[(PRECISION == SINGLE) ? 30 : 62 : (PRECISION == SINGLE) ? 23 : 52], InA[(PRECISION == SINGLE) ? 22 : 51 :0]);
                if(!InA[WIDTH-2 -: EXP_BITS])
                begin
                    if(!InA[FRAC_BITS-1:0])
                        Zero = 1'b1;
                    else
                        Subnormal = 1'b1;
                end
                if(InA[WIDTH-2 -: EXP_BITS] == {EXP_BITS{1'b1}})
                begin
                    if(!InA[FRAC_BITS-1:0])
                        Inf = 1'b1;
                    else
                        NaN = 1'b1;
                end
                Result[0] = Inf & (InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[1] = (InA[(PRECISION == SINGLE) ? 31 : 63]) && !(NaN | Inf | Zero | Subnormal);
                Result[2] = Subnormal & (InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[3] = Zero & (InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[4] = Zero & !(InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[5] = Subnormal & !(InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[6] = !(NaN | Inf | Zero | Subnormal) & !(InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[7] = Inf & !(InA[(PRECISION == SINGLE) ? 31 : 63]);
                Result[8] = NaN & (InA[(PRECISION == SINGLE) ? 22 : 51]); 
                Result[9] = NaN & !(InA[(PRECISION == SINGLE) ? 22 : 51]);
            end
            FCVT_S_W:
            begin
                Result = IntToFloat(InA, 1'b1, round_mode);
                {Subnormal, NaN, Inf, Zero} = classify_value(Result[(PRECISION == SINGLE) ? 30 : 62 : (PRECISION == SINGLE) ? 23 : 52], Result[(PRECISION == SINGLE) ? 22 : 51 :0]);
            end
            FCVT_S_WU:
            begin
                Result = IntToFloat(InA, 1'b0, round_mode);
                {Subnormal, NaN, Inf, Zero} = classify_value(Result[(PRECISION == SINGLE) ? 30 : 62 : (PRECISION == SINGLE) ? 23 : 52], Result[(PRECISION == SINGLE) ? 22 : 51 :0]);
            end
            FMV_S_X:
            begin
                Result = InA;
            end
        endcase
    end


    flp_add_sub #(.PRECISION(PRECISION)) add_sub_unit 
    (
        .a(InAddSubA),
        .b(InAddSubB),
        .round_mode(round_mode),
        .mode(add_sub_mode),
        .Overflow(OverflowAddSub),
        .Underflow(UnderflowAddSub),
        .NaN(NaNAddSub),
        .Inf(InfAddSub),
        .Zero(ZeroAddSub),
        .result(ResultAddSub)
    );

    flp_mul #(.PRECISION(PRECISION)) mul_unit 
    (
        .a(InMulA),
        .b(InMulB),
        .round_mode(round_mode),
        .Overflow(OverflowMul),
        .Underflow(UnderflowMul),
        .NaN(NaNMul),
        .Inf(InfMul),
        .Zero(ZeroMul),
        .result(ResultMul)
    );

    flp_div #(.PRECISION(PRECISION)) div_unit 
    (
        .a(InDivA),
        .b(InDivB),
        .round_mode(round_mode),
        .Overflow(OverflowDiv),
        .Underflow(UnderflowDiv),
        .NaN(NaNDiv),
        .Inf(InfDiv),
        .Zero(ZeroDiv),
        .invalid(InvalidDiv),
        .result(ResultDiv)
    );

    flp_sqrt #(.PRECISION(PRECISION)) sqrt_unit 
    (
        .a(InSqrt),
        .Inf(InfSqrt),
        .NaN(NanSqrt),
        .Zero(ZeroSqrt),
        .result(ResultSqrt)
    );
endmodule: risc_fpu
