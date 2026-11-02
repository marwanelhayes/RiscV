// =============================================================================
// flp_sqrt.sv
// -----------------------------------------------------------------------------
// Floating-point square root unit for RISC-V FPU.
//
// Responsibilities:
//   - Perform the IEEE 754 square root, correctly rounded in every rounding
//     mode (RNE, RTZ, RDN, RUP, RMM)
//   - Handle special cases: NaN -> canonical NaN, -0/+0 -> itself, negative
//     -> canonical NaN, +inf -> +inf
//   - Accept subnormal operands (normalised first)
//   - Multi-cycle restoring digit recurrence, one result bit per cycle
//   - Provide busy/done handshake for flow control
//
// The integer root of the scaled significand is exact, and its remainder
// supplies the sticky bit, so a single final rounding gives the IEEE result.
//
// Parameters:
//   - PRECISION: SINGLE (32-bit) or DOUBLE (64-bit)
//   - WIDTH: Total bit width (32 or 64)
//   - EXP_BITS: Exponent bits (8 for single, 11 for double)
//   - FRAC_BITS: Fraction bits (23 for single, 52 for double)
//   - BIAS: Exponent bias (127 for single, 1023 for double)
//   - STAGES: Kept for interface compatibility (unused)
// =============================================================================
import shared_pkg::*;

module flp_sqrt
#(
    parameter flp_t PRECISION   = SINGLE,
    parameter int   WIDTH       = (PRECISION == SINGLE) ? 32 : 64,
    parameter int   EXP_BITS    = (PRECISION == SINGLE) ? 8  : 11,
    parameter int   FRAC_BITS   = (PRECISION == SINGLE) ? 23 : 52,
    parameter int   BIAS        = (PRECISION == SINGLE) ? 127: 1023,
    parameter int   STAGES      = 4
)(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input   logic clk,                       // Clock signal
    input   logic rst,                       // Asynchronous reset

    // ─── Control and operand inputs ─────────────────────────────────────────
    input   logic valid,                     // Operation valid (start)
    input   logic [WIDTH-1:0] a,             // Input operand (radicand)
    input   round_mode_t round_mode,         // Rounding mode

    // ─── Status outputs ─────────────────────────────────────────────────────
    output  logic busy,                      // Operation in progress
    output  logic done,                      // Operation complete
    output  logic Inf,                       // Result is infinity
    output  logic NaN,                       // Result is NaN
    output  logic Zero,                      // Result is zero

    // ─── Result output ─────────────────────────────────────────────────────
    output  logic [WIDTH-1:0] result         // Floating-point result
);

    localparam int SIG_W  = FRAC_BITS + 1;           // significand incl. hidden bit
    localparam int ROOT_W = SIG_W + 2;               // root bits: significand + guard + 1
    localparam int RAD_W  = 2 * ROOT_W;              // radicand bits
    localparam logic [WIDTH-1:0] CANONICAL_NAN = {1'b0, {EXP_BITS{1'b1}}, 1'b1, {(FRAC_BITS-1){1'b0}}};

    flp_sqrt_state_t state_reg, state_next;
    round_mode_t round_mode_reg, round_mode_next;
    logic [WIDTH-1:0] a_reg, a_next;
    logic [RAD_W-1:0] rad_reg, rad_next;             // radicand, consumed 2 bits per step
    logic [ROOT_W-1:0] root_reg, root_next;          // partial root
    logic [ROOT_W+1:0] rem_reg, rem_next;            // partial remainder
    logic [$clog2(ROOT_W+1)-1:0] count_reg, count_next;
    int unsigned scale_reg, scale_next;              // radicand scale (exponent offset)
    logic signed [EXP_BITS+1:0] exp_reg, exp_next;   // unbiased exponent of the operand
    logic Inf_reg, Inf_next;
    logic NaN_reg, NaN_next;
    logic Zero_reg, Zero_next;
    logic [WIDTH-1:0] result_reg, result_next;

    logic [3:0] class_in;
    logic [SIG_W-1:0] sig;
    logic signed [EXP_BITS+1:0] exp_unb;
    int unsigned scale;
    logic [ROOT_W+1:0] trial;
    logic signed [EXP_BITS+2:0] res_exp;
    logic [SIG_W:0] res_sig;
    logic g, s, up;

    function automatic logic [3:0] classify_value(
        input logic [EXP_BITS-1:0] exp,
        input logic [FRAC_BITS-1:0] frac
    );
        logic [3:0] classification;
        classification[0] = (exp == '0) && (frac == '0);
        classification[1] = (exp == {EXP_BITS{1'b1}}) && (frac == '0);
        classification[2] = (exp == {EXP_BITS{1'b1}}) && (frac != '0);
        classification[3] = (exp == '0) && (frac != '0);
        classify_value = classification;
    endfunction: classify_value

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            state_reg <= SQRT_INIT;
            round_mode_reg <= RNE;
            a_reg <= '0;
            rad_reg <= '0;
            root_reg <= '0;
            rem_reg <= '0;
            count_reg <= '0;
            scale_reg <= '0;
            exp_reg <= '0;
            Inf_reg <= 1'b0;
            NaN_reg <= 1'b0;
            Zero_reg <= 1'b0;
            result_reg <= '0;
        end
        else
        begin
            state_reg <= state_next;
            round_mode_reg <= round_mode_next;
            a_reg <= a_next;
            rad_reg <= rad_next;
            root_reg <= root_next;
            rem_reg <= rem_next;
            count_reg <= count_next;
            scale_reg <= scale_next;
            exp_reg <= exp_next;
            Inf_reg <= Inf_next;
            NaN_reg <= NaN_next;
            Zero_reg <= Zero_next;
            result_reg <= result_next;
        end
    end

    always_comb
    begin: comb
        state_next = state_reg;
        round_mode_next = round_mode_reg;
        a_next = a_reg;
        rad_next = rad_reg;
        root_next = root_reg;
        rem_next = rem_reg;
        count_next = count_reg;
        scale_next = scale_reg;
        exp_next = exp_reg;
        Inf_next = Inf_reg;
        NaN_next = NaN_reg;
        Zero_next = Zero_reg;
        result_next = result_reg;

        class_in = classify_value(a[WIDTH-2 -: EXP_BITS], a[FRAC_BITS-1:0]);
        sig = '0;
        exp_unb = '0;
        scale = 0;
        trial = '0;
        res_exp = '0;
        res_sig = '0;
        g = 1'b0;
        s = 1'b0;
        up = 1'b0;

        busy = (state_reg != SQRT_IDLE) && (state_reg != SQRT_INIT) && (state_reg != SQRT_DONE);
        done = (state_reg == SQRT_DONE);
        Inf = Inf_reg;
        NaN = NaN_reg;
        Zero = Zero_reg;
        result = result_reg;

        case (state_reg)
            SQRT_INIT,
            SQRT_IDLE:
            begin
                state_next = SQRT_IDLE;
                Inf_next = 1'b0;
                NaN_next = 1'b0;
                Zero_next = 1'b0;
                result_next = '0;
                if (valid)
                begin
                    a_next = a;
                    round_mode_next = round_mode;
                    state_next = SQRT_DONE;
                    if (class_in[2])
                    begin
                        result_next = CANONICAL_NAN;             // sqrt(NaN)
                        NaN_next = 1'b1;
                    end
                    else if (class_in[0])
                    begin
                        result_next = a;                         // sqrt(+-0) = +-0
                        Zero_next = 1'b1;
                    end
                    else if (a[WIDTH-1])
                    begin
                        result_next = CANONICAL_NAN;             // negative operand
                        NaN_next = 1'b1;
                    end
                    else if (class_in[1])
                    begin
                        result_next = a;                         // sqrt(+inf) = +inf
                        Inf_next = 1'b1;
                    end
                    else
                    begin
                        state_next = SQRT_NORM;
                    end
                end
            end

            // Normalise the significand and scale it so that the scaled
            // exponent is even: value = sig * 2^(exp - FRAC_BITS) and the
            // radicand is sig << scale with (exp - FRAC_BITS - scale) even.
            SQRT_NORM:
            begin
                if (a_reg[WIDTH-2 -: EXP_BITS] == '0)
                begin
                    sig = {1'b0, a_reg[FRAC_BITS-1:0]};
                    exp_unb = 1 - BIAS;
                    for (int i = 0; i < SIG_W; i++)
                    begin
                        if (!sig[SIG_W-1])
                        begin
                            sig = sig << 1;
                            exp_unb = exp_unb - 1;
                        end
                    end
                end
                else
                begin
                    sig = {1'b1, a_reg[FRAC_BITS-1:0]};
                    exp_unb = $signed({2'b00, a_reg[WIDTH-2 -: EXP_BITS]}) - BIAS;
                end
                scale = RAD_W - SIG_W - 1;
                if (((exp_unb - FRAC_BITS - scale) % 2) != 0)
                    scale = scale + 1;
                rad_next = RAD_W'(sig) << scale;
                scale_next = scale;
                exp_next = exp_unb;
                root_next = '0;
                rem_next = '0;
                count_next = '0;
                state_next = SQRT_ITER;
            end

            // One root bit per cycle (restoring recurrence)
            SQRT_ITER:
            begin
                rem_next = {rem_reg[ROOT_W-1:0], rad_reg[RAD_W-1 -: 2]};
                rad_next = rad_reg << 2;
                trial = {root_reg, 2'b01};
                if (rem_next >= trial)
                begin
                    rem_next = rem_next - trial;
                    root_next = {root_reg[ROOT_W-2:0], 1'b1};
                end
                else
                begin
                    root_next = {root_reg[ROOT_W-2:0], 1'b0};
                end
                count_next = count_reg + 1'b1;
                if (count_reg == ROOT_W - 1)
                    state_next = SQRT_ROUND;
            end

            // root = floor(sqrt(radicand)); its top bit is ROOT_W-1 or ROOT_W-2.
            // sqrt(value) = root * 2^((exp - FRAC_BITS - scale) / 2).
            SQRT_ROUND:
            begin
                res_exp = (exp_reg - FRAC_BITS - $signed(scale_reg)) / 2;
                if (root_reg[ROOT_W-1])
                begin
                    res_sig = {1'b0, root_reg[ROOT_W-1 -: SIG_W]};
                    g = root_reg[ROOT_W-SIG_W-1];
                    s = (root_reg[ROOT_W-SIG_W-2:0] != 0) || (rem_reg != 0);
                    res_exp = res_exp + (ROOT_W - 1);
                end
                else
                begin
                    res_sig = {1'b0, root_reg[ROOT_W-2 -: SIG_W]};
                    g = root_reg[ROOT_W-SIG_W-2];
                    s = (rem_reg != 0);
                    res_exp = res_exp + (ROOT_W - 2);
                end
                case (round_mode_reg)
                    RTZ, RDN: up = 1'b0;                          // result is positive
                    RUP:      up = g | s;
                    RMM:      up = g;
                    default:  up = g & (s | res_sig[0]);          // RNE
                endcase
                res_sig = res_sig + up;
                if (res_sig[SIG_W])
                begin
                    res_sig = res_sig >> 1;
                    res_exp = res_exp + 1;
                end
                result_next = {1'b0, EXP_BITS'(res_exp + BIAS), res_sig[FRAC_BITS-1:0]};
                state_next = SQRT_DONE;
            end

            SQRT_DONE:
            begin
                state_next = SQRT_IDLE;
            end

            default:
            begin
                state_next = SQRT_IDLE;
            end
        endcase
    end: comb

endmodule: flp_sqrt
