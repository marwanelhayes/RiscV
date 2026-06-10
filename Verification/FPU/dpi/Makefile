# =============================================================================
# Makefile - FPU DPI-C Python-backed reference model
# -----------------------------------------------------------------------------
# Builds libfpu_ref.so, which embeds CPython and calls fpu_golden.py.
#   make            # build libfpu_ref.so
#   make clean
#
# Requires the Python development package (python3-dev / libpython3-dev) so
# that <Python.h> and the embed link flags are available.
# =============================================================================

LIB      := libfpu_ref.so
SRC      := fpu_ref.c
HDR      := fpu_ref.h

CC       ?= gcc
CFLAGS   ?= -Wall -Wextra -fPIC -O2 -std=c11

PY_CONFIG := $(shell command -v python3-config)
PY_INC    := $(shell $(PY_CONFIG) --includes 2>/dev/null)
PY_LDF    := $(shell $(PY_CONFIG) --ldflags --embed 2>/dev/null)

LDFLAGS  ?= -shared -lm $(PY_LDF)

.PHONY: all clean

all: $(LIB)

$(LIB): $(SRC) $(HDR)
	$(CC) $(CFLAGS) $(PY_INC) $(SRC) $(LDFLAGS) -o $@

clean:
	rm -f $(LIB) *.o
