import shared_pkg::*;
// IEEE-754 single-precision floating-point divider
// - Format: [31] sign | [30:23] exponent (bias=127) | [22:0] fraction
// - Rounds to nExpArest, ties to even
// - Handles NaN/Inf/Zero, normalized operands; gradual underflow supported
module flp_div
#(
    parameter flp_t PRECISION   = SINGLE,
    parameter int   WIDTH       = (PRECISION == SINGLE) ? 32 : 64,
    parameter int   EXP_BITS    = (PRECISION == SINGLE) ? 8  : 11,
    parameter int   FRAC_BITS   = (PRECISION == SINGLE) ? 23 : 52,
    parameter int   BIAS        = (PRECISION == SINGLE) ? 127: 1023,
    parameter int   EXTRA       = (PRECISION == SINGLE) ? 3 : 6
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  round_mode_t round_mode,
    output logic [WIDTH-1:0] result,
    output logic Overflow, Underflow,
    output logic NaN, Inf, Zero,
    output logic        invalid
);

    // Extract fields
    logic SignA, SignB, SignRes;
    logic signed [EXP_BITS+1:0] ExpA, ExpB;
    logic [FRAC_BITS:0] MantA, MantB , MantRes; // +1 for hidden bit
    logic signed [EXP_BITS + 1:0] ExpDiff;

    // Special case flags
    logic AIsZero, BIsZero; //Zero flags
    logic AIsInf,  BIsInf;  //Infinity flags
    logic AIsNan,  BIsNan;  //NaN flags
    logic AIsSub,  BIsSub;  //Subnormal flags

    logic guard, round, sticky;

    logic SubnormalResult;

    logic [$clog2(FRAC_BITS+1)-1:0] LeadZeroCountA, LeadZeroCountB;
    logic MantAIsZero,MantBIsZero;


   function automatic logic [FRAC_BITS + 3:0] NRSWithGRS (
        input  logic [FRAC_BITS:0] dividend,
        input  logic [FRAC_BITS:0] divisor
    );
        // A needs 2 extra bits: 1 for sign, 1 to prevent overflow during additions
        logic signed [FRAC_BITS + 2:0] A; 
        logic signed [FRAC_BITS + 2:0] A_next; // Combinational helper for the loop
        logic [FRAC_BITS + EXTRA:0] Q;         // 27 bits total
        logic signed [FRAC_BITS + 2:0] M;      // Match A's width for clean math
        
        logic g, r, s;
        logic [FRAC_BITS:0] final_quotient;

        // 1. FRACTIONAL INITIALIZATION
        // Dump dividend directly into A. Q starts empty.
        A = {2'b00, dividend}; 
        M = {2'b00, divisor};
        Q = '0; 

        // 2. THE LOOP
        // Run exactly 27 times. A 'for' loop is safer/standard in SV compared to 'foreach' here.
        for (int i = 0; i < (FRAC_BITS + EXTRA + 1); i++) begin
            
            // Step A: Add/Sub FIRST (because the fractions are already aligned)
            if (A[FRAC_BITS + 2]) 
            begin // If A is negative
                A_next = A + M;
            end 
            else 
            begin              // If A is positive
                A_next = A - M;
            end

            // Step B: Update Q with the NEW sign bit
            Q = {Q[FRAC_BITS + EXTRA - 1 : 0], ~A_next[FRAC_BITS + 2]};

            // Step C: Shift A left for the next iteration
            A = A_next << 1;
        end

        // 3. RESTORATION & GRS EXTRACTION
        // We look at A_next for restoration because A was shifted at the very end of the loop
        if (A_next[FRAC_BITS + 2]) begin
            A_next = A_next + M;
        end

        // Extract the 24-bit quotient and the 3 rounding bits
        final_quotient = Q[FRAC_BITS + EXTRA : EXTRA];
        g = Q[EXTRA-1];
        r = Q[EXTRA-2];
        
        // Sticky bit is 1 if the lower Q bits are non-zero, OR if the exact remainder is non-zero
        s = |Q[EXTRA-3:0] | (|A_next); 

        return {final_quotient, g, r, s};
    endfunction

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

    function logic [WIDTH-1:0] Rounding
    (
        input logic sign,
        input logic [EXP_BITS+1:0] exponent_in,
        input logic [FRAC_BITS:0] mantissa,
        input logic g,r,s,
        input round_mode_t mode
    );
        logic                   lsb;
        logic                   tie;         // exactly half-way case
        logic                   round_up;
        logic        [FRAC_BITS:0]     mantissa_in;
        logic        [FRAC_BITS+1:0]   mantissa_out;
        logic signed [EXP_BITS+1:0]    exponent_out;
        logic                   carry_out;
        logic                   inexact;

        // Unpack
        mantissa_in = mantissa; // include hidden bit
        // Facts gathered from GRS
        lsb     = mantissa_in[0];
        inexact = g | r | s;
        tie     = (g == 1'b1) && (r == 1'b0) && (s == 1'b0);
        round_up = 1'b0;
        exponent_out = exponent_in;

        // Decide round_up per mode
        case (mode)
            RNE: begin
                round_up = (g && (r || s)) || (tie && lsb);
            end
            RTZ: begin
                round_up = 1'b0;
            end
            RDN: begin
                round_up = inexact && (sign == 1'b1);
            end
            RUP: begin
                round_up = inexact && (sign == 1'b0);
            end
            RMM: begin
                round_up = g;
            end
            default: begin
                round_up = (g && (r || s)) || (tie && lsb);
            end
        endcase

        if(round_up)
        begin
            mantissa_out = mantissa_in + 1'b1;
        end
        else
        begin
            mantissa_out = mantissa_in;
        end

        if(mantissa_out == (1 << (FRAC_BITS + 1))) // Overflow in mantissa
        begin
            exponent_out = exponent_out + 1;
            mantissa_out = mantissa_out >> 1;
        end

        if (exponent_out[EXP_BITS+1]) 
        begin
            mantissa_out = mantissa_in >> (1-exponent_out);
            Rounding = {sign, {EXP_BITS{1'b0}}, mantissa_out[FRAC_BITS-1:0]}; // Underflow to Zero
            Underflow = !mantissa_out[FRAC_BITS-1:0]; //Indicate underflow occurred
        end
        else if (exponent_out[EXP_BITS]) 
        begin
            Rounding = {sign, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}}; // Overflow to Inf
            Overflow = 1'b1; //Indicate overflow occurred
        end  
        else 
        begin
            Rounding =  {sign, exponent_out[EXP_BITS-1:0], mantissa_out[FRAC_BITS-1:0]}; // Normal
        end
    endfunction: Rounding

    always_comb 
    begin:comb
        SignA = a[WIDTH-1];
        SignB = b[WIDTH-1];
        ExpA  = {2'b0,a[WIDTH-2 -: EXP_BITS]};
        ExpB  = {2'b0,b[WIDTH-2 -: EXP_BITS]};
        MantA = '0;
        MantB = '0;
        ExpDiff = '0;
        invalid = 1'b0;


        SignRes = SignA ^ SignB;
        Overflow=0;
        Underflow=0;
        NaN=0;
        Inf=0;
        Zero=0;

        guard = 0;
        round = 0;
        sticky = 0;
        result = '0;

        {AIsSub , AIsNan , AIsInf , AIsZero} = classify_value(ExpA[EXP_BITS-1:0], a[FRAC_BITS-1:0]);
        {BIsSub , BIsNan , BIsInf , BIsZero} = classify_value(ExpB[EXP_BITS-1:0], b[FRAC_BITS-1:0]);


        // NaN propagation
        if (AIsNan || BIsNan) 
        begin: handle_nan
            result   = 32'h7FC0_0000;
            NaN      = 1'b1; //Stop division operation
        end: handle_nan
        
        else if ((AIsZero && BIsZero) || (AIsInf && BIsInf)) 
        begin: handle_invalid
            result   = 32'h7FC0_0000;
            invalid     = 1'b1; //Stop division operation
            NaN      = 1'b1; //NaN is the result for invalid operations
        end: handle_invalid
        
        else if (!AIsNan && !AIsInf && !AIsZero && BIsZero) 
        begin: handle_div_by_zero
            result   = {SignRes, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}}; // Inf
            Inf      = 1'b1; //Stop division operation
        end: handle_div_by_zero
        
        else if (AIsZero && !BIsZero) 
        begin: handle_zero_numerator   
            result   = {SignRes, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
            Zero     = 1'b1; //Stop division operation
        end: handle_zero_numerator
        
        else if (AIsInf && !BIsInf) 
        begin: handle_infinite_numerator
            result   = {SignRes, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
            Inf      = 1'b1; //Stop division operation
        end: handle_infinite_numerator
        
        else if (!AIsInf && BIsInf) 
        begin: handle_finite_div_inf
            result   = {SignRes, {EXP_BITS{1'b0}}, {FRAC_BITS{1'b0}}};
            Zero     = 1'b1; //Stop division operation
        end: handle_finite_div_inf
        
        else 
        begin: normal_division
            if (AIsSub) 
            begin
                MantA = a[FRAC_BITS-1:0] << LeadZeroCountA;
                ExpA = ExpA - LeadZeroCountA;
            end
            else
            begin          
                MantA = {1'b1, a[FRAC_BITS-1:0]};
            end

            if (BIsSub) 
            begin
                MantB = b[FRAC_BITS-1:0] << LeadZeroCountB;
                ExpB = ExpB - LeadZeroCountB;
            end
            else          
                MantB = {1'b1, b[FRAC_BITS-1:0]};

            if(!ExpA)
                ExpA = 10'b1;
            if(!ExpB)
                ExpB = 10'b1;

            ExpDiff = ExpA - ExpB + BIAS;
            // Perform division using non-restoring divider
            {MantRes, guard, round, sticky} = NRSWithGRS(MantA, MantB);

            if((!MantRes[FRAC_BITS]) && (ExpDiff > 0))
            begin
                MantRes = {MantRes[FRAC_BITS-1:0],guard};
                guard = round;
                round = sticky;
                ExpDiff = ExpDiff - 1'b1;
            end

            result = Rounding(SignRes, ExpDiff, MantRes, guard, round, sticky, round_mode);
            {SubnormalResult, NaN, Inf, Zero} = classify_value(result[WIDTH-2 -: EXP_BITS], result[FRAC_BITS-1:0]);
            
        end: normal_division
    end:comb


lzc_wr #(.WIDTH(FRAC_BITS + 1)) InputALZC(
    .A_in({a[FRAC_BITS-1:0],1'b0}),
    .leading_zeros(LeadZeroCountA),
    .is_zero(MantAIsZero)
);

lzc_wr #(
    .WIDTH(FRAC_BITS + 1)
)InputBLZC(
    .A_in({b[FRAC_BITS-1:0],1'b0}),
    .leading_zeros(LeadZeroCountB),
    .is_zero(MantBIsZero)
);

endmodule