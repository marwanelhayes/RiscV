# =============================================================================
# Makefile - Spike lock-step reference (DPI-C)
# -----------------------------------------------------------------------------
# Builds libspike_dpi.so, which commit_checker loads with +SPIKE.
#   make                          # SPIKE_DIR defaults to ~/tools/spike
#   make SPIKE_DIR=/path/to/spike
#   make clean
#
# Spike (riscv-isa-sim) must be built and installed first:
#   git clone https://github.com/riscv-software-src/riscv-isa-sim spike
#   cd spike && git checkout c20813c1 && git submodule update --init
#   mkdir build && cd build && ../configure --prefix=$HOME/tools/spike
#   make -j && make install        (needs device-tree-compiler for configure)
#   cp libriscv.a libdisasm.a libsoftfloat.a libfesvr.a libfdt.a $HOME/tools/spike/lib
#
# vsim loads its own, older libstdc++ (gcc 7.4). Spike needs a C++20 compiler,
# so Spike and libstdc++ are linked statically and their symbols kept local
# (--exclude-libs): the library only exports the spike_* DPI functions.
# =============================================================================

LIB       := libspike_dpi.so
SRC       := spike_dpi.cc

SPIKE_DIR ?= $(HOME)/tools/spike
QUESTA    ?= $(dir $(shell command -v vsim))..

CXX       ?= g++
CXXFLAGS  ?= -Wall -fPIC -O2 -std=c++20
INCS      := -I$(SPIKE_DIR)/include -I$(QUESTA)/include
SPIKE_A   := $(addprefix $(SPIKE_DIR)/lib/,libriscv.a libdisasm.a libsoftfloat.a libfesvr.a libfdt.a)
LDFLAGS   := -shared -static-libstdc++ -static-libgcc -Wl,--exclude-libs,ALL

.PHONY: all clean

all: $(LIB)

$(LIB): $(SRC)
	$(CXX) $(CXXFLAGS) $(INCS) $(SRC) $(SPIKE_A) $(LDFLAGS) -o $@

clean:
	rm -f $(LIB) *.o
