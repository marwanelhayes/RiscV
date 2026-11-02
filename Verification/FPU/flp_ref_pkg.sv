// =============================================================================
// flp_ref_pkg.sv
// -----------------------------------------------------------------------------
// Bit-exact single-precision floating-point reference (IEEE 754-2008 +
// RISC-V "F" rules), written from the specifications.
//
// Shared by the FPU predictor (flp_predictor_pkg) and the full-core ISA
// golden model (riscv_iss_pkg), so FP arithmetic is judged by one model:
// arithmetic disagreements show up in flp_top, integration errors (operand
// routing, forwarding, destination register, sign extension) in risc_top.
//
// Every arithmetic result is computed exactly with wide integers and rounded
// once (round_pack), so all five rounding modes and subnormals are exact - no
// host float/double arithmetic is involved. RISC-V specifics:
//   - every NaN result is the canonical NaN 0x7FC00000
//   - FMIN/FMAX: -0 < +0; one NaN operand -> the other operand; both NaN ->
//     canonical NaN
//   - FCVT.W[U].S: out-of-range and NaN saturate (NaN -> 2^31-1 / 2^32-1)
//
// The FPU's status outputs (Overflow, Underflow, NaN, Inf, Zero, InvalidDiv)
// are implementation flags, not IEEE fflags; their definitions are kept as
// the FPU documents them and evaluated on the exact result.
// =============================================================================
package flp_ref_pkg;

    import shared_pkg::*;

    localparam int FW = FINAL_FLP_WIDTH;
    localparam int EB = FINAL_FLP_EXP_BITS;
    localparam int FB = FINAL_FLP_FRAC_BITS;
    localparam int WIDE = 320;                  // > 2*254 exponent span + 24 bits

    typedef logic [WIDE-1:0] wide_t;

    // Canonical quiet NaN
    localparam logic [FW-1:0] CANONICAL_NAN = {1'b0, {EB{1'b1}}, 1'b1, {(FB-1){1'b0}}};

    // Finite value = (-1)^sign * m * 2^e
    typedef struct {
        bit          sign;
        bit          nan, snan, inf, zero;
        logic [23:0] m;
        int          e;
    } fp_t;

    function automatic fp_t unpack(logic [31:0] b);
        fp_t u;
        u.sign = b[31];
        u.nan  = (b[30:23] == 8'hFF) && (b[22:0] != 0);
        u.snan = u.nan && !b[22];
        u.inf  = (b[30:23] == 8'hFF) && (b[22:0] == 0);
        u.zero = (b[30:0] == 0);
        if(b[30:23] == 0)
        begin
            u.m = {1'b0, b[22:0]};
            u.e = -149;
        end
        else
        begin
            u.m = {1'b1, b[22:0]};
            u.e = int'(b[30:23]) - 150;
        end
        return u;
    endfunction:unpack

    function automatic int bit_length(wide_t v);
        for(int i = WIDE-1; i >= 0; i--)
            if(v[i]) return i + 1;
        return 0;
    endfunction:bit_length

    // Round (-1)^sign * (mag + sticky_tail) * 2^e to binary32. mag != 0; a set
    // sticky means the exact value is slightly larger than mag * 2^e (by less
    // than half a unit of mag's lsb).
    function automatic logic [31:0] round_pack(bit sign, wide_t mag, int e, bit sticky,
                                               round_mode_t rm);
        int    p, big_e, q, shift, exp_field;
        wide_t n;
        bit    g, s, up, to_inf;
        p     = bit_length(mag);
        big_e = (p - 1) + e;                         // 2^big_e <= |value| < 2^(big_e+1)
        q     = (big_e < -126) ? -149 : big_e - 23;  // weight of the result lsb
        shift = q - e;
        if(shift > 0)
        begin
            if(shift > WIDE)
            begin
                n = '0; g = 1'b0; s = (mag != 0) || sticky;
            end
            else
            begin
                n = mag >> shift;
                g = mag[shift-1];
                s = ((mag & ((wide_t'(1) << (shift-1)) - 1)) != 0) || sticky;
            end
        end
        else
        begin
            n = mag << (-shift);
            g = 1'b0;
            s = sticky;
        end
        case(rm)
            RTZ:     up = 1'b0;
            RDN:     up = (g | s) & sign;
            RUP:     up = (g | s) & ~sign;
            RMM:     up = g;
            default: up = g & (s | n[0]);            // RNE (DYN resolved by the caller)
        endcase
        n = n + up;
        if(n == (wide_t'(1) << 24))
        begin
            n = n >> 1;
            q = q + 1;
        end
        if(n < (wide_t'(1) << 23))
            return {sign, 8'h00, n[22:0]};           // subnormal (or zero after rounding)
        exp_field = q + 150;
        if(exp_field >= 255)
        begin
            to_inf = (rm == RTZ) ? 1'b0 : (rm == RDN) ? sign : (rm == RUP) ? ~sign : 1'b1;
            return to_inf ? {sign, 8'hFF, 23'b0} : {sign, 8'hFE, {23{1'b1}}};
        end
        return {sign, exp_field[7:0], n[22:0]};
    endfunction:round_pack

    // ── Exact operations on finite, non-zero operands ─────────────────────────
    function automatic logic [31:0] exact_add(fp_t a, fp_t b, round_mode_t rm);
        wide_t ma, mb, mag;
        int    e;
        bit    sign;
        e  = (a.e < b.e) ? a.e : b.e;
        ma = wide_t'(a.m) << (a.e - e);
        mb = wide_t'(b.m) << (b.e - e);
        if(a.sign == b.sign)
        begin
            mag = ma + mb; sign = a.sign;
        end
        else if(ma >= mb)
        begin
            mag = ma - mb; sign = a.sign;
        end
        else
        begin
            mag = mb - ma; sign = b.sign;
        end
        if(mag == 0)
            return {(rm == RDN), 31'b0};             // exact cancellation: +0 (-0 in RDN)
        return round_pack(sign, mag, e, 1'b0, rm);
    endfunction:exact_add

    function automatic logic [31:0] exact_mul(fp_t a, fp_t b, round_mode_t rm);
        return round_pack(a.sign ^ b.sign, wide_t'(a.m) * wide_t'(b.m), a.e + b.e, 1'b0, rm);
    endfunction:exact_mul

    function automatic logic [31:0] exact_div(fp_t a, fp_t b, round_mode_t rm);
        localparam int K = 64;                       // extra quotient bits
        wide_t num, quo, rem;
        num = wide_t'(a.m) << K;
        quo = num / wide_t'(b.m);
        rem = num % wide_t'(b.m);
        return round_pack(a.sign ^ b.sign, quo, a.e - b.e - K, (rem != 0), rm);
    endfunction:exact_div

    function automatic logic [31:0] exact_sqrt(fp_t a, round_mode_t rm);
        localparam int K = 64;                       // result gets K fraction bits
        wide_t m, root, bitv, rem;
        int    e;
        m = wide_t'(a.m);
        e = a.e;
        if(e % 2 != 0)                               // make the exponent even
        begin
            m = m << 1;
            e = e - 1;
        end
        m = m << (2*K);
        // Integer square root, one result bit per step
        root = '0;
        rem  = m;
        bitv = wide_t'(1) << (WIDE-2);
        while(bitv > rem) bitv = bitv >> 2;
        while(bitv != 0)
        begin
            if(rem >= root + bitv)
            begin
                rem  = rem - (root + bitv);
                root = (root >> 1) + bitv;
            end
            else
                root = root >> 1;
            bitv = bitv >> 2;
        end
        return round_pack(1'b0, root, (e - 2*K) / 2, (rem != 0), rm);
    endfunction:exact_sqrt

    // ── Comparisons (true IEEE semantics: NaN unordered, -0 == +0) ───────────
    function automatic bit fp_lt(fp_t a, fp_t b, logic [31:0] ab, logic [31:0] bb);
        if(a.nan || b.nan) return 1'b0;
        if(a.zero && b.zero) return 1'b0;
        if(a.sign != b.sign) return a.sign;          // negative < positive (zeros handled above)
        if(a.sign) return (ab[30:0] > bb[30:0]);
        return (ab[30:0] < bb[30:0]);
    endfunction:fp_lt

    function automatic bit fp_eq(fp_t a, fp_t b, logic [31:0] ab, logic [31:0] bb);
        if(a.nan || b.nan) return 1'b0;
        if(a.zero && b.zero) return 1'b1;
        return (ab == bb);
    endfunction:fp_eq

    // FMIN/FMAX ordering: -0 is below +0
    function automatic bit fp_lt_signed_zero(fp_t a, fp_t b, logic [31:0] ab, logic [31:0] bb);
        if(a.zero && b.zero) return a.sign && !b.sign;
        return fp_lt(a, b, ab, bb);
    endfunction:fp_lt_signed_zero

    // ── Conversions ───────────────────────────────────────────────────────────
    function automatic logic [31:0] fcvt_to_int(logic [31:0] ab, round_mode_t rm, bit is_unsigned);
        fp_t   a;
        wide_t n, fracbits;
        bit    g, s, up;
        longint v;
        a = unpack(ab);
        if(a.nan)
            return is_unsigned ? 32'hFFFF_FFFF : 32'h7FFF_FFFF;
        if(a.inf)
            return a.sign ? (is_unsigned ? 32'h0 : 32'h8000_0000)
                          : (is_unsigned ? 32'hFFFF_FFFF : 32'h7FFF_FFFF);
        if(a.e >= 0)
        begin
            if(a.e > 40) return a.sign ? (is_unsigned ? 32'h0 : 32'h8000_0000)
                                       : (is_unsigned ? 32'hFFFF_FFFF : 32'h7FFF_FFFF);
            n = wide_t'(a.m) << a.e; g = 1'b0; s = 1'b0;
        end
        else if(-a.e > 30)
        begin
            n = '0;                                      // m < 2^24, so |value| < 2^-6
            g = 1'b0;
            s = (a.m != 0);
        end
        else
        begin
            n = wide_t'(a.m) >> (-a.e);
            g = a.m[-a.e - 1];
            fracbits = wide_t'(a.m) & ((wide_t'(1) << (-a.e - 1)) - 1);
            s = (fracbits != 0);
        end
        case(rm)
            RTZ:     up = 1'b0;
            RDN:     up = (g | s) & a.sign;
            RUP:     up = (g | s) & ~a.sign;
            RMM:     up = g;
            default: up = g & (s | n[0]);
        endcase
        n = n + up;
        v = a.sign ? -longint'(n[62:0]) : longint'(n[62:0]);
        if(n[WIDE-1:40] != 0) v = a.sign ? -(longint'(1) << 40) : (longint'(1) << 40);
        if(is_unsigned)
        begin
            if(v < 0)                  return 32'h0;
            if(v > 64'sh0_FFFF_FFFF)   return 32'hFFFF_FFFF;
            return v[31:0];
        end
        if(v < -64'sd2147483648)       return 32'h8000_0000;
        if(v >  64'sd2147483647)       return 32'h7FFF_FFFF;
        return v[31:0];
    endfunction:fcvt_to_int

    function automatic logic [31:0] fcvt_from_int(logic [31:0] iv, bit is_unsigned, round_mode_t rm);
        bit          sign;
        logic [31:0] neg;
        wide_t       mag;
        sign = !is_unsigned && iv[31];
        neg  = -iv;                                          // 32-bit two's complement
        mag  = sign ? wide_t'(neg) : wide_t'(iv);            // magnitude of the 32-bit value
        if(mag == 0) return 32'h0;
        return round_pack(sign, mag, 0, 1'b0, rm);
    endfunction:fcvt_from_int

    function automatic int fclass_s(input logic [FW-1:0] bits);
        bit sign = bits[FW-1];
        logic [EB-1:0] exp_bits  = bits[FW-2 -: EB];
        logic [FB-1:0] frac_bits = bits[FB-1:0];
        int c = 0;
        if(exp_bits == {EB{1'b1}}) begin
            if(frac_bits == 0)            c = sign ? (1<<0) : (1<<7);
            else if(frac_bits[FB-1] == 0) c = (1<<8);                // signaling NaN
            else                          c = (1<<9);                // quiet NaN
        end
        else if(exp_bits == 0) begin
            if(frac_bits == 0) c = sign ? (1<<3) : (1<<4);
            else               c = sign ? (1<<2) : (1<<5);
        end
        else                   c = sign ? (1<<1) : (1<<6);
        return c;
    endfunction:fclass_s

    // ── Result and status flags of one FPU operation ─────────────────────────
    function automatic void flp_ref_compute(
        input  fpu_operation_t      operation,
        input  round_mode_t         round_mode,
        input  logic [FW-1:0]       InA,
        input  logic [FW-1:0]       InB,
        output logic                n_Overflow,
        output logic                n_Underflow,
        output logic                n_NaN,
        output logic                n_Inf,
        output logic                n_Zero,
        output logic                n_InvalidDiv,
        output logic [FW-1:0]       n_Result
    );
        fp_t         a, b, bn;
        round_mode_t rm;
        logic [31:0] r;
        a  = unpack(InA);
        b  = unpack(InB);
        rm = (round_mode == DYN) ? RNE : round_mode;     // DYN is resolved by the core

        n_Overflow   = 1'b0;
        n_Underflow  = 1'b0;
        n_NaN        = 1'b0;
        n_Inf        = 1'b0;
        n_Zero       = 1'b0;
        n_InvalidDiv = 1'b0;
        r            = '0;

        case(operation)
            FADD_S, FSUB_S: begin
                bn = b;
                if(operation == FSUB_S) bn.sign = !b.sign;
                if(a.nan || b.nan || (a.inf && bn.inf && (a.sign != bn.sign)))
                    r = CANONICAL_NAN;
                else if(a.inf)           r = {a.sign, 8'hFF, 23'b0};
                else if(bn.inf)          r = {bn.sign, 8'hFF, 23'b0};
                else if(a.zero && bn.zero)
                    r = {(a.sign == bn.sign) ? a.sign : (rm == RDN), 31'b0};
                else if(a.zero)          r = {bn.sign, InB[30:0]};
                else if(bn.zero)         r = InA;
                else                     r = exact_add(a, bn, rm);
                n_Overflow  = (r[30:0] == 31'h7F80_0000) && !a.inf && !b.inf;
                // Exact cancellation (x + -x, x - x) is an exact zero, not an underflow
                n_Underflow = (r[30:0] == 0) && !a.zero && !b.zero &&
                              !((a.sign != bn.sign) && (InA[30:0] == InB[30:0]));
            end
            FMUL_S: begin
                if(a.nan || b.nan || (a.inf && b.zero) || (a.zero && b.inf))
                    r = CANONICAL_NAN;
                else if(a.inf || b.inf)  r = {a.sign ^ b.sign, 8'hFF, 23'b0};
                else if(a.zero || b.zero) r = {a.sign ^ b.sign, 31'b0};
                else                     r = exact_mul(a, b, rm);
                n_Overflow  = (r[30:0] == 31'h7F80_0000) && !a.inf && !b.inf;
                n_Underflow = (r[30:0] == 0) && !a.zero && !b.zero;
            end
            FDIV_S: begin
                if(a.nan || b.nan || (a.inf && b.inf) || (a.zero && b.zero))
                begin
                    r = CANONICAL_NAN;
                    n_InvalidDiv = !(b.zero && !a.zero && !a.inf && !a.nan);
                end
                else if(b.zero)          r = {a.sign ^ b.sign, 8'hFF, 23'b0};
                else if(a.inf)           r = {a.sign ^ b.sign, 8'hFF, 23'b0};
                else if(a.zero || b.inf) r = {a.sign ^ b.sign, 31'b0};
                else
                begin
                    // Only a finite / finite quotient can overflow or underflow
                    r = exact_div(a, b, rm);
                    n_Overflow  = (r[30:0] == 31'h7F80_0000);
                    n_Underflow = (r[30:0] == 0);
                end
            end
            FSQRT_S: begin
                if(a.nan)                r = CANONICAL_NAN;
                else if(a.zero)          r = InA;                    // sqrt(-0) = -0
                else if(a.sign)          r = CANONICAL_NAN;
                else if(a.inf)           r = InA;
                else                     r = exact_sqrt(a, rm);
            end
            FSGNJ_S:   r = {InB[FW-1],            InA[FW-2:0]};
            FSGNJN_S:  r = {~InB[FW-1],           InA[FW-2:0]};
            FSGNJX_S:  r = {InB[FW-1]^InA[FW-1],  InA[FW-2:0]};
            FMIN_S, FMAX_S: begin
                if(a.nan && b.nan)       r = CANONICAL_NAN;
                else if(a.nan)           r = InB;
                else if(b.nan)           r = InA;
                else if(operation == FMIN_S)
                    r = fp_lt_signed_zero(a, b, InA, InB) ? InA : InB;
                else
                    r = fp_lt_signed_zero(b, a, InB, InA) ? InA : InB;
            end
            FCVT_W_S:  r = fcvt_to_int(InA, rm, 1'b0);
            FCVT_WU_S: r = fcvt_to_int(InA, rm, 1'b1);
            FMV_X_S:   r = InA;
            FEQ_S:     r = 32'(fp_eq(a, b, InA, InB));
            FLT_S:     r = 32'(fp_lt(a, b, InA, InB));
            FLE_S:     r = 32'(fp_lt(a, b, InA, InB) || fp_eq(a, b, InA, InB));
            FCLASS_S:  r = 32'(fclass_s(InA));
            FCVT_S_W:  r = fcvt_from_int(InA, 1'b0, rm);
            FCVT_S_WU: r = fcvt_from_int(InA, 1'b1, rm);
            FMV_S_X:   r = InA;
            default:   r = '0;
        endcase

        // Implementation status flags, evaluated on the result value
        if(operation inside {FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S})
        begin
            n_NaN  = (r[30:23] == 8'hFF) && (r[22:0] != 0);
            n_Inf  = (r[30:0] == 31'h7F80_0000);
            n_Zero = (r[30:0] == 0);
        end
        else if(operation == FCLASS_S)
        begin
            n_NaN  = a.nan;
            n_Inf  = a.inf;
            n_Zero = a.zero;
        end
        n_Result = r;
    endfunction:flp_ref_compute

endpackage:flp_ref_pkg
