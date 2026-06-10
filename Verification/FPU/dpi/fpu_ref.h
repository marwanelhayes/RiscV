// =============================================================================
// fpu_ref.h
// -----------------------------------------------------------------------------
// DPI-C interface declarations for the FPU Python-backed reference model.
// The body (fpu_ref.c) embeds CPython and delegates every computation to
// fpu_golden.py - there is no C-math reference path.
// =============================================================================
#ifndef FLP_FPU_REF_H
#define FLP_FPU_REF_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void fpu_ref_init(void);
void fpu_ref_shutdown(void);

// Single-shot reference computation. Inputs are IEEE-754 single-precision
// bit patterns packed into 32-bit signed ints (DPI int). Outputs follow the
// same convention; status flags are byte-wide (DPI byte) returning {0,1}.
//
// operation, round_mode: integer encodings matching shared_pkg enums.
//   fpu_operation_t   { FADD_S=0, FSUB_S=1, FMUL_S=2, FDIV_S=3, FSQRT_S=4,
//                       FSGNJ_S=5, FSGNJN_S=6, FSGNJX_S=7, FMIN_S=8, FMAX_S=9,
//                       FCVT_W_S=10, FCVT_WU_S=11, FMV_X_S=12,
//                       FEQ_S=13, FLT_S=14, FLE_S=15, FCLASS_S=16,
//                       FCVT_S_W=17, FCVT_S_WU=18, FMV_S_X=19,
//                       NOOPERATION=20 }
//   round_mode_t      { RNE=0, RTZ=1, RDN=2, RUP=3, RMM=4, DYN=7 }
void fpu_ref_compute(
    int        operation,
    int        round_mode,
    int        InA_bits,
    int        InB_bits,
    int*       Result_bits,
    int8_t*    Overflow,
    int8_t*    Underflow,
    int8_t*    NaN,
    int8_t*    Inf,
    int8_t*    Zero,
    int8_t*    InvalidDiv
);

#ifdef __cplusplus
}
#endif

#endif // FLP_FPU_REF_H
