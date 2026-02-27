import shared_pkg::*;

module flp_add_sub 
#(
    parameter flp_t PRECISION   = SINGLE,
    parameter int   WIDTH       = (PRECISION == SINGLE) ? 32 : 64,
    parameter int   EXP_BITS    = (PRECISION == SINGLE) ? 8  : 11,
    parameter int   FRAC_BITS   = (PRECISION == SINGLE) ? 23 : 52,
    parameter int   BIAS        = (PRECISION == SINGLE) ? 127: 1023
)(
    input   logic [WIDTH-1:0] a, b,
    input   mode_t mode,
    input   round_mode_t round_mode,
    output  logic Overflow,Underflow,NaN,Inf,Zero,
    output  logic [WIDTH-1:0] result
);

    // Extract fields
    logic SignA, SignB, SignRes;
    logic [EXP_BITS-1:0] ExpA, ExpB, ExpRes;
    logic [FRAC_BITS:0] MantA, MantB; // +1 for hidden bit
    logic [EXP_BITS:0] ExpDiff;
    logic [3:0] OutFlags; // {is_subnormal, is_nan, is_inf, is_zero}

    logic guard, round, sticky;

    logic SubnormalResult;

    // Special case flags
    logic AIsZero, BIsZero; //Zero flags
    logic AIsInf,  BIsInf;  //Infinity flags
    logic AIsNan,  BIsNan;  //NaN flags
    logic AIsSub,  BIsSub;  //Subnormal flags

    // Classification function that returns 4-bit encoded status
    // Bit 3: is_subnormal, Bit 2: is_nan, Bit 1: is_infinity, Bit 0: is_zero
    function automatic logic [3:0] classify_value(
        input logic [EXP_BITS-1:0] exp,
        input logic [FRAC_BITS-1:0] frac
    );
        logic [3:0] classification;
        
        if((!exp) && (!frac)) //IsZero
        begin
            classification[0] = 1'b1;
        end
        else
        begin
            classification[0] = 1'b0;
        end
        
        if((exp == {EXP_BITS{1'b1}}) && (!frac)) //IsInfinity
        begin
            classification[1] = 1'b1;
        end
        else
        begin
            classification[1] = 1'b0;
        end

        if((exp == {EXP_BITS{1'b1}}) && (|frac)) //IsNaN
        begin
            classification[2] = 1'b1;
        end
        else
        begin
            classification[2] = 1'b0;
        end

        if((!exp) && (|frac)) //IsSubnormal
        begin
            classification[3] = 1'b1;
        end
        else
        begin
            classification[3] = 1'b0;
        end
        classify_value = classification;
        //return classification;
    endfunction: classify_value



    /* This function aligns the mantissa with shift and calculates guard, round, and sticky bits */
    function automatic [FRAC_BITS + 3:0] AlignWithShiftGRS
    (
        input  logic [FRAC_BITS:0] mant_in,   // hidden+frac (FRAC_BITS+1 bits)
        input  logic [EXP_BITS:0]  sh        // shift amount (ExpDiff)
    );
        logic [FRAC_BITS:0] mant_out;
        logic g, r, s; // guard, round, sticky bits

        if (sh == 0) 
        begin
            mant_out = mant_in;
            g = 0; 
            r = 0; 
            s = 0;
        end
        else if (sh <= FRAC_BITS+1) 
        begin
            mant_out  =  mant_in >> sh;
            g = mant_in[sh-1];
            r = (sh >= 2) ? mant_in[sh-2] : 0;
            if (sh >= 3) 
            begin
                for (int i = 0; i < FRAC_BITS; i++)
                begin
                    if(i < sh-2)
                        s = s | mant_in[i];
                end
            end 
            else 
            begin
                s = 0;
            end
        end 
        else 
        begin
            mant_out = '0;
            g = 0;
            r = 0;
            s = |mant_in;
        end
        AlignWithShiftGRS = {mant_out, g, r, s};
    endfunction :AlignWithShiftGRS

    function logic [WIDTH-1:0] Rounding
    (
        input logic [WIDTH-1:0]      in,
        input logic g,r,s,
        input round_mode_t mode
    );
        logic                   lsb;
        logic                   tie;         // exactly half-way case
        logic                   round_up;
        logic [FRAC_BITS:0]     mantissa_in;
        logic [FRAC_BITS+1:0]   mantissa_out;
        logic [EXP_BITS-1:0]    exponent_in;
        logic [EXP_BITS-1:0]    exponent_out;
        logic                   sign;
        logic                   carry_out;
        logic                   inexact;

        // Unpack
        sign     = in[WIDTH-1];
        mantissa_in = {1'b1, in[FRAC_BITS-1:0]}; // include hidden bit
        exponent_in  = in[WIDTH-2 -: EXP_BITS];

        // Facts gathered from GRS
        lsb     = mantissa_in[0];
        inexact = (g | r | s);
        tie     = (g == 1'b1) && (r == 1'b0) && (s == 1'b0);

        // Decide round_up per mode
        case (mode)
            RNE: begin
                /* Round to nearest, ties to even:
                   If > half ULP: g && (r || s) -> round up
                   If tie exactly: g && !r && !s -> round up iff LSB is 1 (to make result even) */
                round_up = (g && (r || s)) || (tie && lsb);
            end
            RTZ: begin
                /* Toward zero: truncate */
                round_up = 1'b0;
            end
            RDN: begin
                /* Toward -inf: round up in magnitude only if negative and inexact */
                round_up = inexact && (sign == 1'b1);
            end
            RUP: begin
                /* Toward +inf: round up only if positive and inexact */
                round_up = inexact && (sign == 1'b0);
            end
            RMM: begin
                /* Nearest, ties to max magnitude (away from zero on ties):
                   - If > half ULP: round up
                   - If tie: round up regardless of LSB
                   Observed compact rule: round_up = g */
                round_up = g;
            end
            default: begin
                /* Fallback to RNE if an unsupported code appears */
                round_up = (g && (r || s)) || (tie && lsb);
            end
        endcase

        // Apply rounding
        if (round_up) 
        begin
            mantissa_out = mantissa_in + 1'b1;
        end 
        else 
        begin
            mantissa_out = mantissa_in;
        end

        if(mantissa_out[FRAC_BITS+1] == 1'b1) // Overflow in mantissa
        begin
            exponent_out = exponent_in + 1;
            mantissa_out = mantissa_out >> 1;
        end
        else
        begin
            exponent_out = exponent_in;
            mantissa_out = mantissa_out;
        end

        Rounding = {sign, exponent_out, mantissa_out[FRAC_BITS-1:0]}; // discard hidden bit and overflow bit
    endfunction: Rounding

    /*  
        This function performs true addition of two floating-point numbers 
        It assumes that the exponents are already aligned and mantissas are shifted accordingly 
        It also assumes that the signs of both numbers are the same 
        It returns the resulting floating-point number after addition and the new guard, round and sticky bits 
    */
    function automatic logic [WIDTH+2:0] TrueAddition 
    (
        input logic [EXP_BITS-1:0] exp_a, input logic [EXP_BITS-1:0] exp_b,
        input logic [EXP_BITS-1:0] exp_res, input logic sign_a,
        input logic [FRAC_BITS:0] mant_a, input logic [FRAC_BITS:0] mant_b,
        input logic g , r, s
    );
        logic [FRAC_BITS+1:0] mant_sum;
        logic [EXP_BITS:0] exp_diff;
        logic [EXP_BITS-1:0] exp_res_internal;
        logic sign_res;
        logic g_out, r_out, s_out;

        exp_res_internal = exp_res;
        mant_sum = mant_a + mant_b;
        sign_res = sign_a;

        // Normalize
        if (mant_sum[FRAC_BITS+1] && (exp_res_internal != 0)) 
        begin
            g_out = mant_sum[0];
            r_out = g;
            s_out = r | s;
            mant_sum = mant_sum >> 1;
            exp_res_internal  = exp_res_internal + 1;
        end 

        if(exp_res_internal == {EXP_BITS{1'b1}}) // Overflow to ± Infinity
        begin
            g_out = g;
            r_out = r;
            s_out = s;
            TrueAddition = {sign_res, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}} , g_out, r_out, s_out};
            Overflow = 1;
            //Inf = 1;
        end
        else
        begin
            g_out = g;
            r_out = r;
            s_out = s;
            TrueAddition = {sign_res, exp_res_internal[EXP_BITS-1:0], mant_sum[FRAC_BITS-1:0] , g_out, r_out, s_out};
        end
    endfunction: TrueAddition

    /*  
        This function performs true subtraction of two floating-point numbers 
        It assumes that the exponents are already aligned and mantissas are shifted accordingly 
        It also assumes that the signs of both numbers are not the same 
        It returns the resulting floating-point number after subtraction  
        Note: Guard, round and sticky bits are not returned as they are not updated in subtraction as there is no shift right operation that discards bits
    */
    
    function automatic logic [WIDTH-1:0] TrueSubtraction 
    (
        input logic [EXP_BITS-1:0] exp_a, input logic [EXP_BITS-1:0] exp_b,
        input logic [EXP_BITS-1:0] exp_res,input logic sign_a,
        input logic [FRAC_BITS:0] mant_a, input logic [FRAC_BITS:0] mant_b
    );
        logic [FRAC_BITS:0] mant_sum;
        logic [EXP_BITS:0] exp_diff;
        logic [EXP_BITS-1:0] exp_res_internal;
        logic sign_res;

        exp_res_internal = exp_res;
        mant_sum = '0;

        if(mant_a < mant_b)
        begin
            mant_sum = mant_b - mant_a;
            sign_res = ~sign_a;
        end
        else
        begin
            mant_sum = mant_a - mant_b;
            sign_res = sign_a;
        end

        if(!mant_sum) // Result is exactly zero
        begin
            TrueSubtraction = {sign_res, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
            //Zero = 1;
        end
        else
        begin

            for (int i = 0; ((i < FRAC_BITS) && (mant_sum[FRAC_BITS] == 0) && ($unsigned(exp_res_internal) > 0)); i++) 
            begin
                mant_sum = mant_sum << 1;
                exp_res_internal  = exp_res_internal - 1'b1;
            end

            if(exp_res_internal == 'b0) // Underflow to ± 0
            begin
                TrueSubtraction = {sign_res, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
                //Zero = 1;
                Underflow = 1;
            end
            else
            begin
                TrueSubtraction = {sign_res, exp_res_internal, mant_sum[FRAC_BITS-1:0]};
            end
        end
    endfunction: TrueSubtraction



    always_comb 
    begin:comb
        // Unpack
        SignA = a[WIDTH-1];
        SignB = b[WIDTH-1];
        SignRes = 0;
        ExpA  = a[WIDTH-2 -: EXP_BITS];
        ExpB  = b[WIDTH-2 -: EXP_BITS];
        ExpRes = 0;

        guard = 0; 
        round = 0; 
        sticky = 0;

        MantA = '0;
        MantB = '0;
        ExpDiff = '0;

        Overflow=0;
        Underflow=0;
        NaN=0;
        Inf=0;
        Zero=0;
        OutFlags = 0;

        {AIsSub , AIsNan , AIsInf , AIsZero} = classify_value(ExpA, a[FRAC_BITS-1:0]);
        {BIsSub , BIsNan , BIsInf , BIsZero} = classify_value(ExpB, b[FRAC_BITS-1:0]);

        // Default result
        result = '0;

        // Handle NaN first
        if (AIsNan || BIsNan) 
        begin: NotANumber
            result = {1'b0, {EXP_BITS{1'b1}}, {1'b1, {(FRAC_BITS-1){1'b0}}}}; // quiet NaN
            NaN=1;
        end: NotANumber

        // Handle infinities
        else if (AIsInf && BIsInf) 
        begin: Infinity
            if (SignA != SignB)
            begin
                result = {1'b0, {EXP_BITS{1'b1}}, {1'b1, {(FRAC_BITS-1){1'b0}}}}; // NaN
                NaN = 1;
            end
            else
            begin
                result = {SignA, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}}; // ±Inf
                Inf=1;
            end
        end: Infinity
        else if (AIsInf) 
        begin: AInf
            result = {SignA, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
            Inf=1;
        end: AInf
        else if (BIsInf) 
        begin: BInf
            Inf=1;
            if(mode == ADD_FLP)
                result = {SignB, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}}; // ±Inf
            else 
                result = {~SignB, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
        end: BInf

        // Handle zeros
        else if (AIsZero && BIsZero) 
        begin: BothZero
            result = {SignA & SignB, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}}; // signed zero
            Zero=1;
        end: BothZero
        else if (AIsZero) 
        begin: AZero
            if(mode == ADD_FLP)
                result = b;
            else 
                result = {~SignB, ExpB, b[FRAC_BITS-1:0]}; // Negate B for subtraction
        end: AZero
        else if (BIsZero) 
        begin: BZero
            result = a;
        end: BZero

        // Normal/Subnormal path
        else 
        begin: NormalOperation
            // Mantissa setup
            if (AIsSub) 
                MantA = {1'b0, a[FRAC_BITS-1:0]};
            else          
                MantA = {1'b1, a[FRAC_BITS-1:0]};

            if (BIsSub) 
                MantB = {1'b0, b[FRAC_BITS-1:0]};
            else          
                MantB = {1'b1, b[FRAC_BITS-1:0]};

            // Align exponents
            if (ExpA > ExpB) 
            begin
                ExpDiff = ExpA - ExpB;
                {MantB, guard, round, sticky} = AlignWithShiftGRS(MantB, ExpDiff);
                ExpRes  = ExpA;
            end 
            else 
            begin
                ExpDiff = ExpB - ExpA;
                {MantA, guard, round, sticky} = AlignWithShiftGRS(MantA, ExpDiff);
                ExpRes  = ExpB;
            end

            case(mode)
                ADD_FLP: 
                begin
                    if(SignA == SignB)
                    begin
                        {result, guard, round, sticky} = TrueAddition(ExpA, ExpB, ExpRes, SignA, MantA, MantB, guard, round, sticky);
                    end
                    else
                    begin
                        result = TrueSubtraction(ExpA, ExpB, ExpRes, SignA, MantA, MantB);
                    end
                end
                SUB_FLP: 
                begin
                    if(SignA == SignB)
                    begin
                        result = TrueSubtraction(ExpA, ExpB, ExpRes, SignA, MantA, MantB);
                    end
                    else
                    begin
                        {result, guard, round, sticky} = TrueAddition(ExpA, ExpB, ExpRes, SignA, MantA, MantB, guard, round, sticky);
                    end
                end
            endcase
            result = Rounding(result, guard, round, sticky, round_mode);
            {SubnormalResult , NaN , Inf , Zero} = classify_value(result[WIDTH-2 -: EXP_BITS], result[FRAC_BITS-1:0]);
        end: NormalOperation
    end:comb
endmodule