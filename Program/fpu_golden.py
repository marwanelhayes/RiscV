"""
fpu_golden.py
-----------------------------------------------------------------------------
Python golden reference for the FPU verification environment.

Called by fpu_ref.c via the embedded CPython interpreter (DPI-C). Public entry
point:

    compute(operation: int, round_mode: int, inA_bits: int, inB_bits: int)
        -> (Result_bits: int, Overflow, Underflow, NaN, Inf, Zero, InvalidDiv)

All bit fields are 32-bit signed ints (matching DPI-C int). Status flags
return 0/1.

Written from IEEE 754-2008 and the RISC-V "F" chapter, independently of the
RTL: every arithmetic result is computed exactly with fractions / integer
square roots and rounded once, in all five rounding modes, with subnormals.
RISC-V specifics: every NaN result is the canonical NaN 0x7FC00000; FMIN/FMAX
treat -0 < +0 and return the non-NaN operand; FCVT.W[U].S saturate (NaN ->
2^31-1 / 2^32-1). The status flags are the FPU's implementation flags, with
the same definitions as Verification/FPU/flp_ref_pkg.sv.

This is the ONLY reference body used by the DPI path (the C file embeds and
calls into this module; there is no separate C-math reference).
"""
from __future__ import annotations
from fractions import Fraction
from math import isqrt

# fpu_operation_t encodings (must match shared_pkg::fpu_operation_t)
FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S = 0, 1, 2, 3, 4
FSGNJ_S, FSGNJN_S, FSGNJX_S, FMIN_S, FMAX_S = 5, 6, 7, 8, 9
FCVT_W_S, FCVT_WU_S, FMV_X_S, FEQ_S, FLT_S, FLE_S = 10, 11, 12, 13, 14, 15
FCLASS_S, FCVT_S_W, FCVT_S_WU, FMV_S_X, NOOPERATION = 16, 17, 18, 19, 20

# round_mode_t encodings (must match shared_pkg::round_mode_t)
RNE, RTZ, RDN, RUP, RMM, DYN = 0, 1, 2, 3, 4, 7

QNAN_BITS = 0x7FC00000
POS_INF_BITS = 0x7F800000
HUGE = Fraction(10 ** 60)                       # stands in for infinity when ordering


def _u32(x: int) -> int:
    return x & 0xFFFFFFFF


def _s32(x: int) -> int:
    x = _u32(x)
    return x - 0x100000000 if x & 0x80000000 else x


def _decode(b: int):
    """(kind, sign, exact value) with kind in 'nan', 'inf', 'num'."""
    s = (b >> 31) & 1
    e = (b >> 23) & 0xFF
    f = b & 0x7FFFFF
    if e == 0xFF:
        return ('nan' if f else 'inf'), s, None
    v = Fraction(f, 1 << 149) if e == 0 else Fraction(f | (1 << 23)) * Fraction(2) ** (e - 150)
    return 'num', s, (-v if s else v)


def _round_f32(x: Fraction, rnd: int, sticky: bool = False) -> int:
    """Round x (plus a sticky tail below its last bit, same sign) to binary32."""
    sign = 1 if x < 0 else 0
    m = -x if sign else x
    e = m.numerator.bit_length() - m.denominator.bit_length()
    if Fraction(2) ** e > m:
        e -= 1
    if Fraction(2) ** (e + 1) <= m:
        e += 1                                  # 2**e <= m < 2**(e+1)
    q = (e - 23) if e >= -126 else -149         # weight of the result lsb
    scaled = m / (Fraction(2) ** q)
    n = scaled.numerator // scaled.denominator
    rem = scaled - n
    half = Fraction(1, 2)
    inexact = rem > 0 or sticky
    if rnd == RTZ:   up = False
    elif rnd == RDN: up = inexact and sign == 1
    elif rnd == RUP: up = inexact and sign == 0
    elif rnd == RMM: up = rem >= half
    else:            up = rem > half or (rem == half and (sticky or (n & 1) == 1))
    n += int(up)
    if n == 1 << 24:                            # carry out of the significand
        n >>= 1
        q += 1
    if n < (1 << 23):                           # subnormal (q == -149)
        return (sign << 31) | n
    exp_field = q + 23 + 127
    if exp_field >= 255:                        # overflow: inf unless rounding toward zero
        to_inf = {RTZ: False, RDN: sign == 1, RUP: sign == 0}.get(rnd, True)
        return (sign << 31) | (POS_INF_BITS if to_inf else 0x7F7FFFFF)
    return (sign << 31) | (exp_field << 23) | (n - (1 << 23))


def _sqrt_f32(v: Fraction, rnd: int) -> int:
    k = 80                                      # extra root bits
    t = (v.numerator * v.denominator) << (2 * k)
    r = isqrt(t)
    return _round_f32(Fraction(r, v.denominator << k), rnd, sticky=(r * r != t))


def _cvt_to_int(kind, sign, v, rnd, unsigned):
    if kind == 'nan':
        return 0xFFFFFFFF if unsigned else 0x7FFFFFFF
    if kind == 'inf':
        if sign:
            return 0 if unsigned else 0x80000000
        return 0xFFFFFFFF if unsigned else 0x7FFFFFFF
    fl = v.numerator // v.denominator           # floor
    rem = v - fl
    half = Fraction(1, 2)
    if rnd == RTZ:   r = fl if v >= 0 else -((-v).numerator // (-v).denominator)
    elif rnd == RDN: r = fl
    elif rnd == RUP: r = fl if rem == 0 else fl + 1
    elif rnd == RMM: r = fl + 1 if (rem > half or (rem == half and v > 0)) else fl
    else:            r = fl + 1 if (rem > half or (rem == half and (fl & 1))) else fl
    lo, hi = (0, 0xFFFFFFFF) if unsigned else (-2 ** 31, 2 ** 31 - 1)
    return max(lo, min(hi, r)) & 0xFFFFFFFF


def _order_key(kind, sign, v, signed_zero):
    """Exact value used for ordering; infinities map to +-HUGE."""
    if kind == 'inf':
        return -HUGE if sign else HUGE
    if signed_zero and v == 0:
        return Fraction(-1, 10 ** 80) if sign else Fraction(0)     # -0 below +0
    return v


def compute(operation: int, round_mode: int, inA_bits: int, inB_bits: int):
    ua = _u32(inA_bits)
    ub = _u32(inB_bits)
    rnd = RNE if round_mode == DYN else round_mode
    ka, sa, va = _decode(ua)
    kb, sb, vb = _decode(ub)
    a_nan, b_nan = ka == 'nan', kb == 'nan'
    a_inf, b_inf = ka == 'inf', kb == 'inf'
    a_zero = ka == 'num' and va == 0
    b_zero = kb == 'num' and vb == 0

    r = 0
    Overflow = Underflow = InvalidDiv = 0

    if operation in (FADD_S, FSUB_S):
        nb = ub ^ 0x80000000 if operation == FSUB_S else ub
        kn, sn, vn = _decode(nb)
        if a_nan or b_nan or (a_inf and b_inf and sa != sn):
            r = QNAN_BITS
        elif a_inf:
            r = ua
        elif b_inf:
            r = nb
        elif a_zero and b_zero:
            r = (sa << 31) if sa == sn else ((rnd == RDN) << 31)
        elif a_zero:
            r = nb
        elif b_zero:
            r = ua
        else:
            x = va + vn
            r = ((rnd == RDN) << 31) if x == 0 else _round_f32(x, rnd)
        Overflow = int((r & 0x7FFFFFFF) == POS_INF_BITS and not a_inf and not b_inf)
        # Exact cancellation (x + -x, x - x) is an exact zero, not an underflow
        Underflow = int((r & 0x7FFFFFFF) == 0 and not a_zero and not b_zero
                        and not (sa != sn and (ua & 0x7FFFFFFF) == (nb & 0x7FFFFFFF)))
    elif operation == FMUL_S:
        if a_nan or b_nan or (a_inf and b_zero) or (a_zero and b_inf):
            r = QNAN_BITS
        elif a_inf or b_inf:
            r = ((sa ^ sb) << 31) | POS_INF_BITS
        elif a_zero or b_zero:
            r = (sa ^ sb) << 31
        else:
            r = _round_f32(va * vb, rnd)
        Overflow = int((r & 0x7FFFFFFF) == POS_INF_BITS and not a_inf and not b_inf)
        Underflow = int((r & 0x7FFFFFFF) == 0 and not a_zero and not b_zero)
    elif operation == FDIV_S:
        if a_nan or b_nan or (a_inf and b_inf) or (a_zero and b_zero):
            r = QNAN_BITS
            InvalidDiv = 0 if (b_zero and not a_zero and not a_inf and not a_nan) else 1
        elif b_zero or a_inf:
            r = ((sa ^ sb) << 31) | POS_INF_BITS
        elif a_zero or b_inf:
            r = (sa ^ sb) << 31
        else:                                   # only finite / finite can over/underflow
            r = _round_f32(va / vb, rnd)
            Overflow = int((r & 0x7FFFFFFF) == POS_INF_BITS)
            Underflow = int((r & 0x7FFFFFFF) == 0)
    elif operation == FSQRT_S:
        if a_nan:
            r = QNAN_BITS
        elif a_zero:
            r = ua                              # sqrt(-0) = -0
        elif sa:
            r = QNAN_BITS
        elif a_inf:
            r = ua
        else:
            r = _sqrt_f32(va, rnd)
    elif operation == FSGNJ_S:  r = (ua & 0x7FFFFFFF) | (ub & 0x80000000)
    elif operation == FSGNJN_S: r = (ua & 0x7FFFFFFF) | ((~ub) & 0x80000000)
    elif operation == FSGNJX_S: r = (ua & 0x7FFFFFFF) | ((ua ^ ub) & 0x80000000)
    elif operation in (FMIN_S, FMAX_S):
        if a_nan and b_nan:
            r = QNAN_BITS
        elif a_nan:
            r = ub
        elif b_nan:
            r = ua
        else:
            xa, xb = _order_key(ka, sa, va, True), _order_key(kb, sb, vb, True)
            r = (ua if xa < xb else ub) if operation == FMIN_S else (ua if xa > xb else ub)
    elif operation == FCVT_W_S:  r = _cvt_to_int(ka, sa, va, rnd, False)
    elif operation == FCVT_WU_S: r = _cvt_to_int(ka, sa, va, rnd, True)
    elif operation == FMV_X_S:   r = ua
    elif operation in (FEQ_S, FLT_S, FLE_S):
        if a_nan or b_nan:
            r = 0
        else:
            xa, xb = _order_key(ka, sa, va, False), _order_key(kb, sb, vb, False)
            r = int({FEQ_S: xa == xb, FLT_S: xa < xb, FLE_S: xa <= xb}[operation])
    elif operation == FCLASS_S:
        e = (ua >> 23) & 0xFF
        f = ua & 0x7FFFFF
        if e == 0xFF:
            if f == 0:           r = (1 << 0) if sa else (1 << 7)
            elif (f >> 22) == 0: r = 1 << 8     # signaling NaN
            else:                r = 1 << 9     # quiet NaN
        elif e == 0:
            if f == 0:           r = (1 << 3) if sa else (1 << 4)
            else:                r = (1 << 2) if sa else (1 << 5)
        else:                    r = (1 << 1) if sa else (1 << 6)
    elif operation in (FCVT_S_W, FCVT_S_WU):
        iv = ua if (operation == FCVT_S_WU or not (ua >> 31)) else ua - (1 << 32)
        r = 0 if iv == 0 else _round_f32(Fraction(iv), rnd)
    elif operation == FMV_S_X:   r = ua
    else:                        r = 0

    NaN = Inf = Zero = 0
    if operation in (FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S):
        NaN = int(((r >> 23) & 0xFF) == 0xFF and (r & 0x7FFFFF) != 0)
        Inf = int((r & 0x7FFFFFFF) == POS_INF_BITS)
        Zero = int((r & 0x7FFFFFFF) == 0)
    elif operation == FCLASS_S:
        NaN, Inf, Zero = int(a_nan), int(a_inf), int(a_zero)

    return (_s32(r), Overflow, Underflow, NaN, Inf, Zero, InvalidDiv)
