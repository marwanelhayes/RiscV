import shared_pkg::*;

module flp_mul
#(
    parameter flp_t PRECISION   = SINGLE,
    parameter int   WIDTH       = (PRECISION == SINGLE) ? 32 : 64,
    parameter int   EXP_BITS    = (PRECISION == SINGLE) ? 8  : 11,
    parameter int   FRAC_BITS   = (PRECISION == SINGLE) ? 23 : 52,
    parameter int   BIAS        = (PRECISION == SINGLE) ? 127: 1023
)(
    input  logic [WIDTH-1:0] a, b,
    input  round_mode_t round_mode,            
    output logic Overflow, Underflow, NaN, Inf, Zero,
    output logic [WIDTH-1:0] result
);

    // Extract fields
    logic SignA, SignB, SignRes;
    logic [EXP_BITS-1:0] ExpA, ExpB;
    logic [EXP_BITS+1:0] ExpRes;
    logic [FRAC_BITS:0] MantA, MantB; // +1 for hidden bit
    logic [((2*FRAC_BITS)+1):0] MantMult;     // +1 for hidden bit

    // Special case flags
    logic AIsZero, BIsZero; //Zero flags
    logic AIsInf,  BIsInf;  //Infinity flags
    logic AIsNan,  BIsNan;  //NaN flags
    logic AIsSub,  BIsSub;  //Subnormal flags

    logic guard, round, sticky;

    logic SubRes;

    logic [EXP_BITS:0] shift_amt; // +1 bit to handle shift amounts up to EXP_BITS (for subnormal handling)
    logic [FRAC_BITS:0] mant_sub;

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

    function automatic logic [((2*FRAC_BITS) + 1):0] BoothMult
    (
        input logic [FRAC_BITS:0] mant_a, input logic [FRAC_BITS:0] mant_b
    );

    logic [(2*FRAC_BITS) + 1:0] accumulator;
    logic [(2*FRAC_BITS) + 1:0] multiplicand_used;
    logic [FRAC_BITS + 2:0] multiplier_used;
    integer i;

    accumulator = '0;
    multiplicand_used = {{(FRAC_BITS+1){1'b0}}, mant_a[FRAC_BITS:0]};
    multiplier_used = {1'b0,mant_b[FRAC_BITS:0], 1'b0};


    for (i = 0; i < FRAC_BITS+2; i = i + 1) 
    begin
        case ({multiplier_used[i+1], multiplier_used[i]})   // take 2 bits at a time starting from bit i and going upwards for a total of 2 bits
            2'b01: accumulator = accumulator + (multiplicand_used << i);   // +multiplicand shifted
            2'b10: accumulator = accumulator - (multiplicand_used << i);   // -multiplicand shifted
            default: accumulator = accumulator; // no operation
        endcase
    end
    BoothMult =  accumulator;
    endfunction: BoothMult

    function automatic logic [2:0] ExtractGRS
    (
        input logic [FRAC_BITS - 1:0] mantissa
    );
        logic g , r , s;
        g = mantissa[FRAC_BITS - 1];
        r = mantissa[FRAC_BITS - 2];
        s = |mantissa[FRAC_BITS - 3:0];
        ExtractGRS = {g, r, s};
    endfunction: ExtractGRS

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
        exponent_out = exponent_in;

        // Facts gathered from GRS
        lsb     = mantissa_in[0];
        inexact = g | r | s;
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
        // Perform rounding
        if (round_up)
        begin
            mantissa_out = mantissa_in + 1;
            if(mantissa_out == (1 << (FRAC_BITS + 1))) // Check for mantissa overflow (e.g., 1.111... + 0.000... = 10.000...)
            begin
                exponent_out = exponent_out + 1;
                mantissa_out = mantissa_out >> 1;
            end
        end
        else
        begin
            mantissa_out = mantissa_in;
        end

        Rounding = {sign, exponent_out, mantissa_out[FRAC_BITS-1:0]}; // discard hidden bit and overflow bit
    endfunction: Rounding

    always_comb 
    begin:comb
        // Unpack
        SignA = a[WIDTH-1];
        SignB = b[WIDTH-1];
        SignRes = 0;
        ExpA  = a[WIDTH-2 -: EXP_BITS];
        ExpB  = b[WIDTH-2 -: EXP_BITS];
        ExpRes = 0;

        MantA = '0;
        MantB = '0;
        Overflow=0;
        Underflow=0;
        NaN=0;
        Inf=0;
        Zero=0;

        guard = 0;
        round = 0;
        sticky = 0;

        SubRes = 0;

        shift_amt = '0;

        // Detect special cases
        {AIsSub , AIsNan , AIsInf , AIsZero} = classify_value(ExpA, a[FRAC_BITS-1:0]);
        {BIsSub , BIsNan , BIsInf , BIsZero} = classify_value(ExpB, b[FRAC_BITS-1:0]);

        // Default result
        result = '0;

        // Handle NaN first
        if (AIsNan || BIsNan || ((AIsInf || BIsInf) && (AIsZero || BIsZero)))
        begin
            NaN = 1;
            result = {1'b0, {EXP_BITS{1'b1}}, {1'b1, {(FRAC_BITS-1){1'b0}}}}; // quiet NaN
        end
        // Infinity cases
        else if (AIsInf || BIsInf) 
        begin
            SignRes = SignA ^ SignB;
            Inf = 1;
            result = {SignRes, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
        end
        // Zero cases
        else if (AIsZero || BIsZero) 
        begin
            SignRes = SignA ^ SignB;
            Zero = 1;
            result = {SignRes, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
        end


        // Normal/Subnormal path
        else 
        begin
            // Mantissa setup
            if (AIsSub) 
                MantA = {1'b0, a[FRAC_BITS-1:0]};
            else          
                MantA = {1'b1, a[FRAC_BITS-1:0]};

            if (BIsSub) 
                MantB = {1'b0, b[FRAC_BITS-1:0]};
            else          
                MantB = {1'b1, b[FRAC_BITS-1:0]};
            
            // Multiply mantissas using Booth's algorithm
            MantMult = BoothMult(MantA, MantB);
            // Determine sign of the result
            SignRes = SignA ^ SignB;

            // Determine exponent
            ExpRes = ExpA - BIAS + ExpB; // Add exponents and remove bias

            // Normalize result
            if(MantMult[(2*FRAC_BITS)+1] == 1'b1) // if the highest bit is 1
            begin
                MantMult = MantMult >> 1;
                ExpRes = ExpRes + 1;  
            end

            
            if (ExpRes[EXP_BITS + 1]) // Check for underflow (exponent is negative)
            begin
                Underflow = 0;
                Zero = 0;
                // Shift mantissa into subnormal range
                shift_amt = 1 - ExpRes; 
                mant_sub = MantMult[((2*FRAC_BITS)-1) -: (FRAC_BITS)] >> shift_amt;
                if (mant_sub == 0) 
                begin
                    Zero = 1;
                    Underflow = 1;
                    result = {SignRes, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}}; // true zero
                end 
                else 
                begin
                    result = {SignRes, {EXP_BITS{1'b0}}, mant_sub[FRAC_BITS-1:0]}; // subnormal
                end
            end
            else if(ExpRes >= (2**EXP_BITS - 1)) // Check for overflow (exponent exceeds max representable value)
            begin
                Overflow = 1;
                Inf = 1;
                result = {SignRes, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}}; // Infinity
            end
            else
            begin
            // Rounding bits extraction
                {guard, round, sticky} = ExtractGRS(MantMult[FRAC_BITS-1:0]);   
                result = {SignRes, ExpRes[EXP_BITS-1:0], MantMult[((2*FRAC_BITS)-1) -: (FRAC_BITS)]};
                result = Rounding(result, guard, round, sticky, round_mode);
                {SubRes , NaN , Inf , Zero} = classify_value(result[WIDTH-2 -: EXP_BITS], result[FRAC_BITS-1:0]);
                //Underflow = Zero;
            end
        end 
    end:comb
endmodule