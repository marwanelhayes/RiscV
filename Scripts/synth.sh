#!/usr/bin/env bash
# Yosys synthesis of riscv_processor (generic gates, slang SV frontend).
# Usage: Scripts/synth.sh [XLEN]   (default 32). Outputs land in <repo>/Scratch/syn/out_rv<XLEN>/ (wiped per run).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
rm -rf "$REPO/Scratch/syn"; mkdir -p "$REPO/Scratch/syn"
cd "$REPO/Scratch/syn"   # INSTR_MEM_PATH "../../Program/Dump/binary1.txt" resolves from here

XLEN=${1:-32}
YOSYS=${YOSYS:-$HOME/tools/oss-cad-suite/bin/yosys}
OUT=out_rv$XLEN
D=$REPO/Design
mkdir -p "$OUT"

"$YOSYS" -l "$OUT/synth.log" -p "
plugin -i slang
read_slang -D XLEN=$XLEN -I $D --top riscv_processor \
    $D/shared_pkg.sv $(ls $D/*.sv | grep -vE 'shared_pkg|csr_defs' | tr '\n' ' ')
synth -top riscv_processor -run :fine
# stock 'fine' step minus memory_map: memories stay \$mem cells (SRAM/BRAM macros)
opt -fast -full; opt -full; techmap; opt -fast; abc -script \"+strash;dretime;map\"; opt -fast
hierarchy -check; check
tee -o $OUT/stat.txt stat
write_verilog -noattr $OUT/riscv_processor_netlist.v
"
