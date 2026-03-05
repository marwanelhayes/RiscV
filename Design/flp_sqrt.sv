import shared_pkg::*;

//y  = y * ( threehalfs - ( x2 * y * y ) );
//Y is InMagic
//X2 is In Half

module flp_sqrt 
#(
    parameter flp_t PRECISION   = SINGLE,
    parameter int   WIDTH       = (PRECISION == SINGLE) ? 32 : 64,
    parameter int   EXP_BITS    = (PRECISION == SINGLE) ? 8  : 11,
    parameter int   FRAC_BITS   = (PRECISION == SINGLE) ? 23 : 52,
    parameter int   BIAS        = (PRECISION == SINGLE) ? 127: 1023
)(
    input   logic [WIDTH-1:0] a,
    output  logic Inf, NaN, Zero, 
    output  logic [WIDTH-1:0] result
);

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

    localparam logic [(PRECISION == SINGLE) ? 32 : 64] MAGIC = (PRECISION == SINGLE) ? 'h5f3759df : 'h5fe6eb50c7b537a9; //A7A
    localparam logic [31:0] THREE_HALFS = 32'h3f_c0_00_00;

    
    // Extract fields
    logic Sign;
    logic [EXP_BITS-1:0] Exp;
    logic [FRAC_BITS-1:0] Mant;
    logic [EXP_BITS-1:0] ExpHalf;
    logic [WIDTH-1:0] InHalf;
    logic [WIDTH-1:0] InMagic;
    logic [WIDTH-1:0] Result1 , Result2 , Result3 , Result4 , Result5;
    logic Subnormal;
    logic InfIn, NaNIn, ZeroIn,SubnormalIn;

    always_comb
    begin
        Sign = a[WIDTH-1];
        Exp  = a[WIDTH-2 -: EXP_BITS];
        Mant = a[FRAC_BITS-1:0];
        {SubnormalIn,NaNIn,InfIn,ZeroIn} = classify_value(Exp,Mant);
        if(SubnormalIn)
        begin
            InHalf = {Sign, Exp, Mant};
            InMagic = MAGIC - (a >> 1);            
        end
        else
        begin
            ExpHalf = Exp - 1;
            InHalf = {Sign, ExpHalf, Mant};
            InMagic = MAGIC - (a >> 1);
        end
    end

    always_comb
    begin
        Zero = 1'b0;
        NaN = 1'b0;
        Inf = 1'b0;
        Subnormal = 1'b0;
        if(Sign)
        begin
            NaN = 1'b1;
            result = 32'h7FC00000;
        end
        else if(NaNIn || InfIn || ZeroIn)
        begin
            result = a;
            NaN = NaNIn;
            Inf = InfIn;
            Zero = ZeroIn;
        end
        else
        begin
            {Subnormal, NaN, Inf, Zero} = classify_value(Result5[WIDTH-2 -: EXP_BITS], Result5[FRAC_BITS-1:0]);
            result = Result5;
        end
    end

    flp_mul #(.PRECISION(PRECISION)) MUL1 (
        .a(InHalf),
        .b(InMagic),
        .result(Result1)
    );

    flp_mul #(.PRECISION(PRECISION)) MUL2 (
        .a(Result1),
        .b(InMagic),
        .result(Result2)
    );

    flp_add_sub #(.PRECISION(PRECISION)) ADD_SUB (
        .a(THREE_HALFS),
        .b(Result2),
        .mode(SUB_FLP),
        .result(Result3)
    );

    flp_mul #(.PRECISION(PRECISION)) MUL3 (
        .a(Result3),
        .b(InMagic),
        .result(Result4)
    );

    flp_mul #(.PRECISION(PRECISION)) MUL4 (
        .a(a),
        .b(Result4),
        .result(Result5)
    );

endmodule
