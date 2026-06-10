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

This is the ONLY reference body used by the DPI path (the C file embeds and
calls into this module; there is no separate C-math reference).
"""
from __future__ import annotations
import math
import struct

# fpu_operation_t encodings (must match shared_pkg::fpu_operation_t)
FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S = 0, 1, 2, 3, 4
FSGNJ_S, FSGNJN_S, FSGNJX_S, FMIN_S, FMAX_S = 5, 6, 7, 8, 9
FCVT_W_S, FCVT_WU_S, FMV_X_S, FEQ_S, FLT_S, FLE_S = 10, 11, 12, 13, 14, 15
FCLASS_S, FCVT_S_W, FCVT_S_WU, FMV_S_X, NOOPERATION = 16, 17, 18, 19, 20

# round_mode_t encodings (must match shared_pkg::round_mode_t)
RNE, RTZ, RDN, RUP, RMM, DYN = 0, 1, 2, 3, 4, 7

QNAN_BITS = 0x7FC00000
POS_INF_BITS = 0x7F800000


def _u32(x: int) -> int:
    return x & 0xFFFFFFFF


def _s32(x: int) -> int:
    x = _u32(x)
    return x - 0x100000000 if x & 0x80000000 else x


def _bits_to_f(b: int) -> float:
    return struct.unpack('<f', struct.pack('<I', _u32(b)))[0]


def _f_to_bits(f: float) -> int:
    # struct.pack('<f', x) raises OverflowError when |x| exceeds the binary32
    # range instead of saturating, so a finite double that rounds out of range
    # must be mapped to the correctly-signed infinity (matches IEEE / the DUT).
    try:
        return _s32(struct.unpack('<I', struct.pack('<f', f))[0])
    except (OverflowError, struct.error):
        return _s32(0xFF800000 if f < 0 else POS_INF_BITS)


def _is_nan(b: int) -> bool:
    b = _u32(b); return ((b >> 23) & 0xFF) == 0xFF and (b & 0x7FFFFF) != 0


def _is_inf(b: int) -> bool:
    b = _u32(b); return ((b >> 23) & 0xFF) == 0xFF and (b & 0x7FFFFF) == 0


def _is_zero(b: int) -> bool:
    return (_u32(b) & 0x7FFFFFFF) == 0


def _sign(b: int) -> int:
    return (_u32(b) >> 31) & 1


# Bit width constants (single precision)
_FRAC_BITS = 23
_BIAS = 127


def _int_to_float_bits(int_in: int, sign_or_unsign: int, rnd: int) -> int:
    """Integer -> float32 bits, replicating the DUT (int_to_float_bits):
    magnitude of the signed value is converted, the result sign is
    (msb & sign_or_unsign), and rounding follows round_mode."""
    int_in = _u32(int_in)
    sign = (int_in >> 31) & 1
    abs_val = _u32(-int_in) if sign else int_in
    if abs_val == 0:
        return 0
    msb = abs_val.bit_length() - 1
    exponent = msb + _BIAS
    shifted = _u32(abs_val << (31 - msb))      # leading 1 at bit 31
    mantissa = (shifted >> (31 - _FRAC_BITS)) & ((1 << _FRAC_BITS) - 1)
    if rnd == RNE:   rud = mantissa & 1
    elif rnd == RTZ: rud = 0
    elif rnd == RDN: rud = -1 if sign else 0
    elif rnd == RUP: rud = 1 if not sign else 0
    elif rnd == RMM: rud = 1
    else:            rud = mantissa & 1
    mantissa = (mantissa + rud) & ((1 << (_FRAC_BITS + 1)) - 1)
    if mantissa == (1 << _FRAC_BITS):
        mantissa = 0
        exponent += 1
    out_sign = sign & sign_or_unsign
    bits = ((out_sign & 1) << 31) | ((exponent & 0xFF) << _FRAC_BITS) \
        | (mantissa & ((1 << _FRAC_BITS) - 1))
    return _s32(bits)


def _fcvt_float_to_int(val: float, rnd: int, is_unsigned: int) -> int:
    """float32 -> int, replicating the DUT (fcvt_float_to_int): round per
    round_mode then saturate to the signed/unsigned 32-bit range."""
    if math.isnan(val):
        return _s32(0x7FFFFFFF)
    fl = math.floor(val)
    diff = val - fl
    fl = int(fl)
    if rnd == RNE or rnd == DYN:
        if diff < 0.5:   r = fl
        elif diff > 0.5: r = fl + 1
        else:            r = fl if (fl % 2 == 0) else fl + 1
    elif rnd == RTZ:
        r = fl if val >= 0.0 else int(math.ceil(val))
    elif rnd == RDN:
        r = fl
    elif rnd == RUP:
        r = int(math.ceil(val))
    elif rnd == RMM:
        if diff < 0.5:   r = fl
        elif diff > 0.5: r = fl + 1
        else:            r = fl + 1 if val >= 0.0 else fl
    else:
        if diff < 0.5:   r = fl
        elif diff > 0.5: r = fl + 1
        else:            r = fl if (fl % 2 == 0) else fl + 1
    if is_unsigned:
        if val >= 4294967295.0 or r >= 0xFFFFFFFF: return _s32(0x7FFFFFFF)
        if val <= 0.0 or r <= 0:                   return 0
        return _s32(r)
    else:
        if val >= 2147483647.0 or r >= 2147483647:    return _s32(0x7FFFFFFF)
        if val <= -2147483648.0 or r <= -2147483648:  return _s32(0x80000000)
        return _s32(r)


def compute(operation: int, round_mode: int, inA_bits: int, inB_bits: int):
    inA_bits = _s32(inA_bits)
    inB_bits = _s32(inB_bits)
    a = _bits_to_f(inA_bits)
    b = _bits_to_f(inB_bits)
    ua = _u32(inA_bits)
    ub = _u32(inB_bits)
    a_nan, b_nan = _is_nan(ua), _is_nan(ub)
    a_inf, b_inf = _is_inf(ua), _is_inf(ub)
    a_zero, b_zero = _is_zero(ua), _is_zero(ub)

    Result = 0
    Overflow = Underflow = NaN = Inf = Zero = InvalidDiv = 0

    def _flags(rb):
        return (1 if _is_nan(rb) else 0,
                1 if _is_inf(rb) else 0,
                1 if _is_zero(rb) else 0)

    if operation == FADD_S:
        r = a + b; rb = _f_to_bits(r)
        NaN, Inf, Zero = _flags(rb)
        Overflow = Inf
        Underflow = 1 if (Zero and not a_zero and not b_zero) else 0
        if NaN: rb = _s32(QNAN_BITS)
        Result = rb
    elif operation == FSUB_S:
        r = a - b; rb = _f_to_bits(r)
        NaN, Inf, Zero = _flags(rb)
        Overflow = Inf
        Underflow = 1 if (ua != ub and Zero and not a_zero and not b_zero) else 0
        if NaN: rb = _s32(QNAN_BITS)
        Result = rb
    elif operation == FMUL_S:
        r = a * b; rb = _f_to_bits(r)
        NaN, Inf, Zero = _flags(rb)
        Overflow = 1 if (Inf and not a_inf and not b_inf) else 0
        Underflow = 1 if (Zero and not a_zero and not b_zero) else 0
        if NaN: rb = _s32(QNAN_BITS)
        Result = rb
    elif operation == FDIV_S:
        if (a_nan or b_nan) or (a_inf and b_inf) or (a_zero and b_zero):
            Result = _s32(QNAN_BITS); NaN = 1
            InvalidDiv = 0 if (b_zero and not a_zero and not a_inf and not a_nan) else 1
        elif (not a_nan and not a_inf and not a_zero and b_zero):
            Result = _s32(((ua ^ ub) & 0x80000000) | POS_INF_BITS); Inf = 1
        else:
            r = a / b; rb = _f_to_bits(r)
            NaN, Inf, Zero = _flags(rb)
            Overflow = Inf
            Underflow = 1 if (Zero and not a_zero) else 0
            InvalidDiv = 1 if b_zero else 0
            Result = rb
    elif operation == FSQRT_S:
        if _sign(ua):
            Result = _s32(QNAN_BITS); NaN = 1
        elif a_nan or a_inf or a_zero:
            Result = _s32(ua)
            NaN, Inf, Zero = (1 if a_nan else 0), (1 if a_inf else 0), (1 if a_zero else 0)
        else:
            r = math.sqrt(a); rb = _f_to_bits(r)
            NaN, Inf, Zero = _flags(rb)
            Result = rb
    elif operation == FSGNJ_S:  Result = _s32((ua & 0x7FFFFFFF) | (ub & 0x80000000))
    elif operation == FSGNJN_S: Result = _s32((ua & 0x7FFFFFFF) | ((~ub) & 0x80000000))
    elif operation == FSGNJX_S: Result = _s32((ua & 0x7FFFFFFF) | ((ua ^ ub) & 0x80000000))
    elif operation == FMIN_S:   Result = inA_bits if a < b else inB_bits
    elif operation == FMAX_S:   Result = inA_bits if a > b else inB_bits
    elif operation == FCVT_W_S:  Result = _fcvt_float_to_int(a, round_mode, 0)
    elif operation == FCVT_WU_S: Result = _fcvt_float_to_int(a, round_mode, 1)
    elif operation == FMV_X_S:   Result = inA_bits
    elif operation == FEQ_S:     Result = 1 if a == b else 0
    elif operation == FLT_S:     Result = 1 if a <  b else 0
    elif operation == FLE_S:     Result = 1 if a <= b else 0
    elif operation == FCLASS_S:
        s = _sign(ua); e = (ua >> 23) & 0xFF; f = ua & 0x7FFFFF
        if e == 0xFF:
            if f == 0:           cls = (1<<0) if s else (1<<7)
            elif (f >> 22) == 0: cls = (1<<8)
            else:                cls = (1<<9)
        elif e == 0:
            if f == 0:           cls = (1<<3) if s else (1<<4)
            else:                cls = (1<<2) if s else (1<<5)
        else:                    cls = (1<<1) if s else (1<<6)
        Result = cls
        NaN, Inf, Zero = (1 if a_nan else 0), (1 if a_inf else 0), (1 if a_zero else 0)
    elif operation == FCVT_S_W:  Result = _int_to_float_bits(inA_bits, 1, round_mode)
    elif operation == FCVT_S_WU: Result = _int_to_float_bits(inA_bits, 0, round_mode)
    elif operation == FMV_S_X:   Result = inA_bits
    else:                        Result = 0

    return (_s32(Result), Overflow, Underflow, NaN, Inf, Zero, InvalidDiv)
