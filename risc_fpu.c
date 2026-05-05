#include <fenv.h>
#include <math.h>
#include <stdint.h>

#pragma STDC FENV_ACCESS ON

// RISC-V fflags bitmask
#define RV_NV (1 << 4) 
#define RV_DZ (1 << 3) 
#define RV_OF (1 << 2) 
#define RV_UF (1 << 1) 
#define RV_NX (1 << 0) 


typedef enum {
    FADD_S      = 0,
    FSUB_S      = 1,
    FMUL_S      = 2,
    FDIV_S      = 3,
    FSQRT_S     = 4,
    FSGNJ_S     = 5,
    FSGNJN_S    = 6,
    FSGNJX_S    = 7,
    FMIN_S      = 8,
    FMAX_S      = 9,
    FCVT_W_S    = 10,
    FCVT_WU_S   = 11,
    FMV_X_S     = 12,
    FEQ_S       = 13,
    FLT_S       = 14,
    FLE_S       = 15,
    FCLASS_S    = 16,
    FCVT_S_W    = 17,
    FCVT_S_WU   = 18,
    FMV_S_X     = 19,
    NOOPERATION = 20
} fpu_operation_t;

float risc_fpu(
    float           fa,
    float           fb,
    int32_t         i_val, // Integer value for FCVT_S_W/WU
    int             rm,    // Rounding mode
    fpu_operation_t op,    // Use your SV typedef here
    int* fflags
) {
    int original_rm = fegetround();
    float res_val = 0.0f;

    // Set Rounding Mode
    switch(rm) {
        case 0: fesetround(FE_TONEAREST);  break;
        case 1: fesetround(FE_TOWARDZERO); break;
        case 2: fesetround(FE_DOWNWARD);   break;
        case 3: fesetround(FE_UPWARD);     break;
        default: fesetround(FE_TONEAREST);
    }

    feclearexcept(FE_ALL_EXCEPT);

    // Execute based on your specific OpCodes
    switch(op) {
        case FADD_S:    res_val = fa + fb; break;
        case FSUB_S:    res_val = fa - fb; break;
        case FMUL_S:    res_val = fa * fb; break;
        case FDIV_S:    res_val = fa / fb; break;
        case FSQRT_S:   res_val = sqrtf(fa); break;
        
        // Integer to Float conversions
        case FCVT_S_W:  res_val = (float)i_val; break;
        case FCVT_S_WU: res_val = (float)((uint32_t)i_val); break;

        // Note: Sign-injection, comparisons, and float-to-int 
        // would go here in a full FPU model.
        case NOOPERATION: res_val = 0.0f; break;
        default:          res_val = 0.0f; break;
    }

    // Capture flags
    int raised = fetestexcept(FE_ALL_EXCEPT);
    *fflags = 0;
    if (raised & FE_INVALID)   *fflags |= RV_NV;
    if (raised & FE_DIVBYZERO) *fflags |= RV_DZ;
    if (raised & FE_OVERFLOW)  *fflags |= RV_OF;
    if (raised & FE_UNDERFLOW) *fflags |= RV_UF;
    if (raised & FE_INEXACT)   *fflags |= RV_NX;

    fesetround(original_rm);
    return res_val;
}