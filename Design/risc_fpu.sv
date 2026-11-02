// =============================================================================
// risc_fpu.sv
// -----------------------------------------------------------------------------
// Floating-Point Unit (FPU) for RISC-V processor.
//
// Responsibilities:
//   - Execute all RV32F floating-point instructions
//   - Dispatch operations to appropriate functional units
//   - Handle move operations between GPR and FPR
//   - Manage multi-cycle operations with busy/done handshake; done and Result
//     stay valid while hold is high (the consumer is stalled)
//   - Generate status flags (overflow, underflow, NaN, infinity, zero)
//
// Instantiates:
//   - flp_add_sub: Addition and subtraction unit
//   - flp_mul: Multiplication unit
//   - flp_div: Division unit
//   - flp_sqrt: Square root unit
//
// Parameters:
//   - PRECISION: SINGLE (32-bit) or DOUBLE (64-bit)
//   - STAGES: Number of pipeline stages for FPU operations
// =============================================================================
import shared_pkg::*;

module risc_fpu #(
    parameter flp_t PRECISION   = SINGLE,
    parameter int   STAGES      = 4
)(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input  logic clk,                       // Clock signal
    input  logic rst,                       // Asynchronous reset

    // ─── Operand inputs ───────────────────────────────────────────────────────
    input  logic valid,                      // Operation valid signal
    input  logic hold,                       // Consumer stalled: keep done/Result until it takes them
    input  logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InA,  // Operand A
    input  logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InB,  // Operand B
    input  fpr_t RdF,                       // Destination FPR index

    // ─── Control inputs ───────────────────────────────────────────────────────
    input  logic RegWrite,                  // FPR write enable
    input  round_mode_t round_mode,         // Rounding mode
    input  fpu_operation_t operation,       // FPU operation type
    input  move_operation_t MoveOperation,  // GPR/FPR move type

    // ─── Status outputs ─────────────────────────────────────────────────────
    output logic busy,                       // FPU busy flag
    output logic done,                       // FPU done flag
    output logic Overflow, Underflow, NaN, Inf, Zero, InvalidDiv,  // Status flags

    // ─── Result outputs ─────────────────────────────────────────────────────
    output logic [ (PRECISION == SINGLE) ? 31 : 63 :0] Result,  // Result
    output fpr_t RdFOut,                    // Destination FPR index (output)
    output logic RegWriteOut,               // FPR write enable (output)
    output move_operation_t MoveOperationOut // Move operation (output)
);

    // ─── Internal wires – operand routing ──────────────────────────────────
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InAddSubA, InAddSubB;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InMulA, InMulB;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InDivA, InDivB;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InSqrt;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] ResultAddSub, ResultMul, ResultDiv, ResultSqrt;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] InA_reg, InB_reg;
    logic [ (PRECISION == SINGLE) ? 31 : 63 :0] Result_reg, Result_selected;

    localparam int WIDTH        = (PRECISION == SINGLE) ? 32 : 64;
    localparam int EXP_BITS     = (PRECISION == SINGLE) ? 8  : 11;
    localparam int FRAC_BITS    = (PRECISION == SINGLE) ? 23 : 52;
    localparam int BIAS         = (PRECISION == SINGLE) ? 127: 1023;
    localparam int WIDTHBITS    = $clog2(WIDTH);
    
    mode_t add_sub_mode;
    logic UseAddSub;
    logic UseMul;
    logic UseDiv;
    logic UseSqrt;

    logic OverflowAddSub, UnderflowAddSub, NaNAddSub, InfAddSub, ZeroAddSub;
    logic OverflowMul, UnderflowMul, NaNMul, InfMul, ZeroMul;
    logic OverflowDiv, UnderflowDiv, NaNDiv, InfDiv, ZeroDiv;
    logic InfSqrt, NanSqrt, ZeroSqrt;
    logic Subnormal,InvalidDivActual;
    logic AddSubBusy, AddSubDone;
    logic MulBusy, MulDone;
    logic DivBusy, DivDone;
    logic SqrtBusy, SqrtDone;
    logic req_valid_reg, req_accept, req_complete, req_uses_module, modules_busy;
    logic done_reg;
    logic Overflow_reg, Underflow_reg, NaN_reg, Inf_reg, Zero_reg, InvalidDiv_reg;
    logic Overflow_selected, Underflow_selected, NaN_selected, Inf_selected, Zero_selected, InvalidDiv_selected;
    logic ClassNaN, ClassInf, ClassZero;
    logic ANaN, BNaN;                       // Operand is a NaN (FMIN/FMAX and compares)
    localparam logic [(PRECISION == SINGLE) ? 31 : 63 :0] CanonicalNaN = {1'b0, {EXP_BITS{1'b1}}, 1'b1, {(FRAC_BITS-1){1'b0}}};
    round_mode_t round_mode_reg;
    fpu_operation_t operation_reg;
    fpr_t RdF_reg;
    logic RegWrite_reg;
    move_operation_t MoveOperation_reg;

    // Float -> 32-bit integer (FCVT.W.S / FCVT.WU.S). The value is rounded
    // once with guard/sticky bits in the requested mode, then saturated as
    // RISC-V specifies: NaN and +inf/too large -> max, -inf/too negative ->
    // min (0 for the unsigned form).
    function automatic logic [WIDTH-1:0] FloatToInt 
    (
        input  logic [WIDTH-1:0] float_in,
        input  logic SignOrUnsign,          // 1 = signed (FCVT.W.S), 0 = unsigned
        input round_mode_t round
    );
        logic sign;
        logic [EXP_BITS-1:0] exponent;
        logic [FRAC_BITS:0] mantissa;       // Including hidden bit
        int exp_unbiased;
        int shift;
        logic [32:0] magnitude;             // Rounded |value|, one carry bit
        logic guard_bit;
        logic sticky_bit;
        logic round_increment;
        logic nan;
        logic inf;

        sign     = float_in[WIDTH-1];
        exponent = float_in[WIDTH-2 -: EXP_BITS];
        mantissa = {(exponent != 0), float_in[FRAC_BITS-1:0]};
        nan      = (exponent == {EXP_BITS{1'b1}}) && (|float_in[FRAC_BITS-1:0]);
        inf      = (exponent == {EXP_BITS{1'b1}}) && !(|float_in[FRAC_BITS-1:0]);
        exp_unbiased = (exponent == 0) ? (1 - BIAS) : (int'(exponent) - BIAS);
        magnitude = '0;
        guard_bit = 1'b0;
        sticky_bit = 1'b0;
        round_increment = 1'b0;

        if(nan)
            return SignOrUnsign ? 32'h7FFF_FFFF : 32'hFFFF_FFFF;
        if(inf || (exp_unbiased >= 32))
        begin
            if(sign)
                return SignOrUnsign ? 32'h8000_0000 : 32'h0000_0000;
            return SignOrUnsign ? 32'h7FFF_FFFF : 32'hFFFF_FFFF;
        end

        // |value| = mantissa * 2^(exp_unbiased - FRAC_BITS)
        shift = FRAC_BITS - exp_unbiased;
        if(shift <= 0)
        begin
            magnitude = 33'(mantissa) << (-shift);
        end
        else if(shift > FRAC_BITS + 1)
        begin
            sticky_bit = |mantissa;                      // |value| < 0.5
        end
        else
        begin
            magnitude = 33'(mantissa >> shift);
            guard_bit = mantissa[shift-1];
            for(int i = 0; i < FRAC_BITS + 1; i++)
                if(i < shift - 1)
                    sticky_bit |= mantissa[i];
        end

        case(round)
            RTZ:     round_increment = 1'b0;
            RDN:     round_increment = sign && (guard_bit || sticky_bit);
            RUP:     round_increment = !sign && (guard_bit || sticky_bit);
            RMM:     round_increment = guard_bit;
            default: round_increment = guard_bit && (sticky_bit || magnitude[0]);
        endcase
        magnitude = magnitude + round_increment;

        if(SignOrUnsign)
        begin
            if(!sign && (magnitude > 33'h0_7FFF_FFFF))
                return 32'h7FFF_FFFF;
            if(sign && (magnitude > 33'h0_8000_0000))
                return 32'h8000_0000;
            return sign ? -magnitude[31:0] : magnitude[31:0];
        end
        if(sign)
            return 32'h0000_0000;                        // negative -> 0
        if(magnitude > 33'h0_FFFF_FFFF)
            return 32'hFFFF_FFFF;
        return magnitude[31:0];
    endfunction: FloatToInt

    // 32-bit integer -> float (FCVT.S.W / FCVT.S.WU), rounded once with
    // guard/sticky bits in the requested mode.
    function automatic logic [WIDTH-1:0] IntToFloat
    (
        input  logic [WIDTH-1:0] int_in,
        input  logic SignOrUnsign,          // 1 = signed (FCVT.S.W), 0 = unsigned
        input  round_mode_t round
    );
        logic sign;
        logic [31:0] abs_val;
        logic [EXP_BITS-1:0] exponent;
        logic [FRAC_BITS+1:0] significand;  // Hidden bit + fraction + carry
        int msb_index;
        int shift;
        logic guard_bit;
        logic sticky_bit;
        logic round_increment;

        sign    = SignOrUnsign && int_in[31];
        abs_val = sign ? -int_in : int_in;
        guard_bit = 1'b0;
        sticky_bit = 1'b0;
        round_increment = 1'b0;
        msb_index = 0;

        if(abs_val == 0)
            return '0;

        for(int i = 0; i < 32; i++)
            if(abs_val[i])
                msb_index = i;
        exponent = EXP_BITS'(msb_index + BIAS);
        shift = msb_index - FRAC_BITS;
        if(shift <= 0)
        begin
            significand = (FRAC_BITS+2)'(abs_val) << (-shift);
        end
        else
        begin
            significand = (FRAC_BITS+2)'(abs_val >> shift);
            guard_bit = abs_val[shift-1];
            for(int i = 0; i < 32; i++)
                if(i < shift - 1)
                    sticky_bit |= abs_val[i];
        end

        case(round)
            RTZ:     round_increment = 1'b0;
            RDN:     round_increment = sign && (guard_bit || sticky_bit);
            RUP:     round_increment = !sign && (guard_bit || sticky_bit);
            RMM:     round_increment = guard_bit;
            default: round_increment = guard_bit && (sticky_bit || significand[0]);
        endcase
        significand = significand + round_increment;
        if(significand[FRAC_BITS+1])                    // rounded up to the next power of two
        begin
            significand = significand >> 1;
            exponent = exponent + 1'b1;
        end
        return {sign, exponent, significand[FRAC_BITS-1:0]};
    endfunction: IntToFloat

    // IEEE ordered less-than; -0 and +0 are equal. Operands are not NaN.
    function automatic logic FpLess(input logic [WIDTH-1:0] a, input logic [WIDTH-1:0] b);
        if((a[WIDTH-2:0] == 0) && (b[WIDTH-2:0] == 0))
            return 1'b0;
        if(a[WIDTH-1] != b[WIDTH-1])
            return a[WIDTH-1];
        if(a[WIDTH-1])
            return a[WIDTH-2:0] > b[WIDTH-2:0];
        return a[WIDTH-2:0] < b[WIDTH-2:0];
    endfunction: FpLess

    // FMIN/FMAX ordering: like FpLess but -0 is below +0
    function automatic logic FpLessSignedZero(input logic [WIDTH-1:0] a, input logic [WIDTH-1:0] b);
        if((a[WIDTH-2:0] == 0) && (b[WIDTH-2:0] == 0))
            return a[WIDTH-1] && !b[WIDTH-1];
        return FpLess(a, b);
    endfunction: FpLessSignedZero

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

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            InA_reg <= '0;
            InB_reg <= '0;
            round_mode_reg <= RNE;
            operation_reg <= FADD_S;
            req_valid_reg <= 1'b0;
            done_reg <= 1'b0;
            Overflow_reg <= 1'b0;
            Underflow_reg <= 1'b0;
            NaN_reg <= 1'b0;
            Inf_reg <= 1'b0;
            Zero_reg <= 1'b0;
            InvalidDiv_reg <= 1'b0;
            Result_reg <= '0;
            RdF_reg <= f0;
            RegWrite_reg <= 1'b0;
            MoveOperation_reg <= FPUToFPU;        
        end
        else
        begin
            if (req_accept)
            begin
                InA_reg <= InA;
                InB_reg <= InB;
                round_mode_reg <= round_mode;
                operation_reg <= operation;
                req_valid_reg <= 1'b1;
                done_reg <= 1'b0;
                RdF_reg <= RdF;
                RegWrite_reg <= RegWrite;
                MoveOperation_reg <= MoveOperation;
            end
            else if (req_complete)
            begin
                Result_reg <= Result_selected;
                Overflow_reg <= Overflow_selected;
                Underflow_reg <= Underflow_selected;
                NaN_reg <= NaN_selected;
                Inf_reg <= Inf_selected;
                Zero_reg <= Zero_selected;
                InvalidDiv_reg <= InvalidDiv_selected;
                done_reg <= 1'b1;
                req_valid_reg <= 1'b0;
            end
            else if(done_reg && !hold)    // Result stays until the consumer advances
            begin
                done_reg <= 1'b0;
                RdF_reg <= f0;
                RegWrite_reg <= 1'b0;
                MoveOperation_reg <= FPUToFPU;
                InA_reg <= '0;
                InB_reg <= '0;
                round_mode_reg <= RNE;
                operation_reg <= FADD_S;
                Result_reg <= '0;
                Overflow_reg <= 1'b0;
                Underflow_reg <= 1'b0;
                NaN_reg <= 1'b0;
                Inf_reg <= 1'b0;
                Zero_reg <= 1'b0;
                InvalidDiv_reg <= 1'b0;
            end
        end
    end

    always_comb
    begin
        InAddSubA   = '0;
        InAddSubB   = '0;
        InMulA      = '0;
        InMulB      = '0;
        InDivA      = '0;
        InDivB      = '0;
        InSqrt      = '0;
        ClassNaN    = 1'b0;
        ClassInf    = 1'b0;
        ClassZero   = 1'b0;
        Subnormal   = 1'b0;
        add_sub_mode = ADD_FLP;
        UseAddSub = 1'b0;
        UseMul = 1'b0;
        UseDiv = 1'b0;
        UseSqrt = 1'b0;
        Result_selected = '0;
        Overflow_selected = 1'b0;
        Underflow_selected = 1'b0;
        NaN_selected = 1'b0;
        Inf_selected = 1'b0;
        Zero_selected = 1'b0;
        InvalidDiv_selected = 1'b0;
        req_uses_module = 1'b0;
        ANaN = (InA_reg[WIDTH-2 -: EXP_BITS] == {EXP_BITS{1'b1}}) && (|InA_reg[FRAC_BITS-1:0]);
        BNaN = (InB_reg[WIDTH-2 -: EXP_BITS] == {EXP_BITS{1'b1}}) && (|InB_reg[FRAC_BITS-1:0]);

        case(operation_reg)
                FADD_S:
                begin
                    InAddSubA       = InA_reg;
                    InAddSubB       = InB_reg;
                    add_sub_mode    = ADD_FLP;
                    UseAddSub       = 1'b1;
                    req_uses_module = 1'b1;
                    Overflow_selected = OverflowAddSub;
                    Underflow_selected = UnderflowAddSub;
                    NaN_selected = NaNAddSub;
                    Inf_selected = InfAddSub;
                    Zero_selected = ZeroAddSub;
                    Result_selected = ResultAddSub;
                end
                FSUB_S:
                begin
                    InAddSubA       = InA_reg;
                    InAddSubB       = InB_reg;
                    add_sub_mode    = SUB_FLP;
                    UseAddSub       = 1'b1;
                    req_uses_module = 1'b1;
                    Overflow_selected = OverflowAddSub;
                    Underflow_selected = UnderflowAddSub;
                    NaN_selected = NaNAddSub;
                    Inf_selected = InfAddSub;
                    Zero_selected = ZeroAddSub;
                    Result_selected = ResultAddSub;
                end
                FMUL_S:
                begin
                    InMulA          = InA_reg;
                    InMulB          = InB_reg;
                    UseMul          = 1'b1;
                    req_uses_module = 1'b1;
                    Overflow_selected = OverflowMul;
                    Underflow_selected = UnderflowMul;
                    NaN_selected = NaNMul;
                    Inf_selected = InfMul;
                    Zero_selected = ZeroMul;
                    Result_selected = ResultMul;
                end
                FDIV_S:
                begin
                    InDivA          = InA_reg;
                    InDivB          = InB_reg;
                    UseDiv          = 1'b1;
                    req_uses_module = 1'b1;
                    Overflow_selected = OverflowDiv;
                    Underflow_selected = UnderflowDiv;
                    NaN_selected = NaNDiv;
                    Inf_selected = InfDiv;
                    Zero_selected = ZeroDiv;
                    InvalidDiv_selected = InvalidDivActual;
                    Result_selected = ResultDiv;
                end
                FSQRT_S:
                begin
                    InSqrt          = InA_reg;
                    UseSqrt         = 1'b1;
                    req_uses_module = 1'b1;
                    NaN_selected = NanSqrt;
                    Inf_selected = InfSqrt;
                    Zero_selected = ZeroSqrt;
                    Result_selected = ResultSqrt;
                end
                FSGNJ_S:
                begin
                    Result_selected = {InB_reg[(PRECISION == SINGLE) ? 31 : 63], InA_reg[(PRECISION == SINGLE) ? 30 : 62 :0]};
                end
                FSGNJN_S:
                begin
                    Result_selected = {~InB_reg[(PRECISION == SINGLE) ? 31 : 63], InA_reg[(PRECISION == SINGLE) ? 30 : 62 :0]};
                end
                FSGNJX_S:
                begin
                    Result_selected = {InA_reg[(PRECISION == SINGLE) ? 31 : 63] ^ InB_reg[(PRECISION == SINGLE) ? 31 : 63], InA_reg[(PRECISION == SINGLE) ? 30 : 62 :0]};
                end
                FMIN_S, FMAX_S:
                begin
                    // -0 < +0; one NaN operand -> the other one; two NaNs -> canonical NaN
                    if(ANaN && BNaN)
                        Result_selected = CanonicalNaN;
                    else if(ANaN)
                        Result_selected = InB_reg;
                    else if(BNaN)
                        Result_selected = InA_reg;
                    else if(operation_reg == FMIN_S)
                        Result_selected = FpLessSignedZero(InA_reg, InB_reg) ? InA_reg : InB_reg;
                    else
                        Result_selected = FpLessSignedZero(InB_reg, InA_reg) ? InA_reg : InB_reg;
                end
                FCVT_W_S:
                begin
                    Result_selected = FloatToInt(InA_reg, 1'b1, round_mode_reg);
                end
                FCVT_WU_S:
                begin
                    Result_selected = FloatToInt(InA_reg, 1'b0, round_mode_reg);
                end
                FMV_X_S:
                begin
                    Result_selected = InA_reg;
                end
                FEQ_S:
                begin
                    Result_selected = (!ANaN && !BNaN &&
                                       ((InA_reg == InB_reg) ||
                                        ((InA_reg[WIDTH-2:0] == 0) && (InB_reg[WIDTH-2:0] == 0)))) ? 1 : 0;
                end
                FLT_S:
                begin
                    Result_selected = (!ANaN && !BNaN && FpLess(InA_reg, InB_reg)) ? 1 : 0;
                end
                FLE_S:
                begin
                    Result_selected = (!ANaN && !BNaN &&
                                       (FpLess(InA_reg, InB_reg) || (InA_reg == InB_reg) ||
                                        ((InA_reg[WIDTH-2:0] == 0) && (InB_reg[WIDTH-2:0] == 0)))) ? 1 : 0;
                end
                FCLASS_S:
                begin
                    if(!InA_reg[WIDTH-2 -: EXP_BITS])
                    begin
                        if(!InA_reg[FRAC_BITS-1:0])
                            ClassZero = 1'b1;
                        else
                            Subnormal = 1'b1;
                    end
                    if(InA_reg[WIDTH-2 -: EXP_BITS] == {EXP_BITS{1'b1}})
                    begin
                        if(!InA_reg[FRAC_BITS-1:0])
                            ClassInf = 1'b1;
                        else
                            ClassNaN = 1'b1;
                    end
                    Zero_selected = ClassZero;
                    Inf_selected = ClassInf;
                    NaN_selected = ClassNaN;
                    Result_selected[0] = ClassInf & (InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[1] = (InA_reg[(PRECISION == SINGLE) ? 31 : 63]) && !(ClassNaN | ClassInf | ClassZero | Subnormal);
                    Result_selected[2] = Subnormal & (InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[3] = ClassZero & (InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[4] = ClassZero & !(InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[5] = Subnormal & !(InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[6] = !(ClassNaN | ClassInf | ClassZero | Subnormal) & !(InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[7] = ClassInf & !(InA_reg[(PRECISION == SINGLE) ? 31 : 63]);
                    Result_selected[8] = ClassNaN & !(InA_reg[(PRECISION == SINGLE) ? 22 : 51]);   // signaling NaN
                    Result_selected[9] = ClassNaN & (InA_reg[(PRECISION == SINGLE) ? 22 : 51]);    // quiet NaN
                end
                FCVT_S_W:
                begin
                    Result_selected = IntToFloat(InA_reg, 1'b1, round_mode_reg);
                end
                FCVT_S_WU:
                begin
                    Result_selected = IntToFloat(InA_reg, 1'b0, round_mode_reg);          
                end
                FMV_S_X:
                begin
                    Result_selected = InA_reg;
                end
            endcase
    end

    always_comb
    begin
        modules_busy = AddSubBusy | MulBusy | DivBusy | SqrtBusy;
        req_accept = valid && !req_valid_reg && !modules_busy;
        req_complete = 1'b0;

        if (req_valid_reg)
        begin
            if (req_uses_module)
            begin
                if (UseSqrt)
                    req_complete = SqrtDone;
                else
                req_complete = ((UseAddSub && AddSubDone) || (UseMul && MulDone) || (UseDiv && DivDone) || (UseSqrt && SqrtDone));
            end
            else
                req_complete = 1'b1;
        end
    end

    assign busy = req_valid_reg;
    assign done = done_reg;
    assign Overflow = Overflow_reg;
    assign Underflow = Underflow_reg;
    assign NaN = NaN_reg;
    assign Inf = Inf_reg;
    assign Zero = Zero_reg;
    assign InvalidDiv = InvalidDiv_reg;
    assign Result = Result_reg;
    
    always_comb
    begin
        MoveOperationOut = FPUToFPU;
        RdFOut = f0;
        RegWriteOut = 1'b0;
        if(done_reg)
        begin
            MoveOperationOut = MoveOperation_reg;
            RdFOut = RdF_reg;
            RegWriteOut = RegWrite_reg;
        end
    end

    flp_add_sub #(.PRECISION(PRECISION)) add_sub_unit 
    (
        .a(InAddSubA),
        .b(InAddSubB),
        .clk(clk),
        .rst(rst),
        .valid(req_valid_reg & UseAddSub),
        .round_mode( round_mode_reg),
        .mode(add_sub_mode),
        .busy(AddSubBusy),
        .done(AddSubDone),
        .Overflow(OverflowAddSub),
        .Underflow(UnderflowAddSub),
        .NaN(NaNAddSub),
        .Inf(InfAddSub),
        .Zero(ZeroAddSub),
        .result(ResultAddSub)
    );

    flp_mul #(.PRECISION(PRECISION),.STAGES(STAGES)) mul_unit 
    (
        .a(InMulA),
        .b(InMulB),
        .clk(clk),
        .rst(rst),
        .valid(req_valid_reg & UseMul),
        .round_mode(round_mode_reg),
        .busy(MulBusy),
        .done(MulDone),
        .Overflow(OverflowMul),
        .Underflow(UnderflowMul),
        .NaN(NaNMul),
        .Inf(InfMul),
        .Zero(ZeroMul),
        .result(ResultMul)
    );

    flp_div #(.PRECISION(PRECISION),.STAGES(STAGES)) div_unit 
    (
        .a(InDivA),
        .b(InDivB),
        .clk(clk),
        .rst(rst),
        .valid(req_valid_reg & UseDiv),
        .round_mode(round_mode_reg),
        .busy(DivBusy),
        .done(DivDone),
        .Overflow(OverflowDiv),
        .Underflow(UnderflowDiv),
        .NaN(NaNDiv),
        .Inf(InfDiv),
        .Zero(ZeroDiv),
        .invalid(InvalidDivActual),
        .result(ResultDiv)
    );

    flp_sqrt #(.PRECISION(PRECISION),.STAGES(STAGES)) sqrt_unit 
    (
        .clk(clk),
        .rst(rst),
        .valid(req_valid_reg & UseSqrt),
        .a(InSqrt),
        .round_mode(round_mode_reg),
        .busy(SqrtBusy),
        .done(SqrtDone),
        .Inf(InfSqrt),
        .NaN(NanSqrt),
        .Zero(ZeroSqrt),
        .result(ResultSqrt)
    );
endmodule: risc_fpu
