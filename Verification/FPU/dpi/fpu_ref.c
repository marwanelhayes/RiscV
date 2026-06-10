// =============================================================================
// fpu_ref.c
// -----------------------------------------------------------------------------
// DPI-C reference model body for the FPU verification environment.
//
// Python-only: every computation is delegated to fpu_golden.py through an
// embedded CPython interpreter. There is intentionally NO C-math reference
// path here - the C layer exists solely to wrap the Python golden model so it
// can be called from SystemVerilog over DPI-C.
//
// Build (see Makefile):   make            -> libfpu_ref.so (python-backed)
// The Python module is located at runtime via the FLP_DPI_DIR environment
// variable (set by the sim do-file to .../Verification/FPU/dpi).
// =============================================================================
#include "fpu_ref.h"

#include <stdio.h>
#include <stdint.h>
#include <Python.h>

static PyObject* g_py_module     = NULL;
static PyObject* g_py_compute_fn = NULL;
static int       g_init_done     = 0;

void fpu_ref_init(void)
{
    if(g_init_done) return;
    Py_Initialize();
    PyRun_SimpleString(
        "import sys, os\n"
        "sys.path.insert(0, os.environ.get('FLP_DPI_DIR','.'))\n"
    );
    g_py_module = PyImport_ImportModule("fpu_golden");
    if(g_py_module) {
        g_py_compute_fn = PyObject_GetAttrString(g_py_module, "compute");
    } else {
        PyErr_Print();
    }
    g_init_done = 1;
    if(g_py_compute_fn)
        fprintf(stdout, "[fpu_ref] reference model initialised (python golden via DPI-C)\n");
    else
        fprintf(stderr, "[fpu_ref] ERROR: failed to load fpu_golden.compute (check FLP_DPI_DIR)\n");
    fflush(stdout);
}

void fpu_ref_shutdown(void)
{
    if(!g_init_done) return;
    Py_XDECREF(g_py_compute_fn);
    Py_XDECREF(g_py_module);
    Py_Finalize();
    g_init_done     = 0;
    g_py_compute_fn = NULL;
    g_py_module     = NULL;
}

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
    int8_t*    InvalidDiv)
{
    // Safe defaults in case the Python call fails.
    *Result_bits = 0;
    *Overflow = *Underflow = *NaN = *Inf = *Zero = *InvalidDiv = 0;

    if(!g_init_done) fpu_ref_init();
    if(!g_py_compute_fn) {
        fprintf(stderr, "[fpu_ref] ERROR: compute called before Python golden was loaded\n");
        return;
    }

    PyObject* args = Py_BuildValue("(iiii)", operation, round_mode,
                                   (int)InA_bits, (int)InB_bits);
    PyObject* res  = PyObject_CallObject(g_py_compute_fn, args);
    Py_DECREF(args);
    if(!res) { PyErr_Print(); return; }

    int result_bits, ov, uf, nan_, inf_, zero_, inv;
    if(!PyArg_ParseTuple(res, "iiiiiii", &result_bits,
                         &ov, &uf, &nan_, &inf_, &zero_, &inv)) {
        PyErr_Print();
        Py_DECREF(res);
        return;
    }
    *Result_bits = result_bits;
    *Overflow    = (int8_t)ov;
    *Underflow   = (int8_t)uf;
    *NaN         = (int8_t)nan_;
    *Inf         = (int8_t)inf_;
    *Zero        = (int8_t)zero_;
    *InvalidDiv  = (int8_t)inv;
    Py_DECREF(res);
}
