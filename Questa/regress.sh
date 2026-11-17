#!/usr/bin/env bash
# =============================================================================
# regress.sh
# -----------------------------------------------------------------------------
# Headless regression: every testbench top x every XLEN x N random seeds,
# one PASS/FAIL table at the end. Exit status is 0 only if every run passes.
#
# Per XLEN the sources are compiled once in a scratch area outside the repo
# (compile.do with +define+XLEN=<n> added to every vlog). Per seed a fresh
# random program is generated with the same seed that drives -sv_seed, so a
# failing row is reproduced exactly with: regress.sh -x <xlen> -s <seed> -t <top>
#
# A run passes when it reaches the UVM report summary with 0 UVM_ERROR and
# 0 UVM_FATAL. Logs and UCDBs stay in $WORK/x<xlen>/q/run/logs.
#
# Usage: Questa/regress.sh [-n N] [-s "seed ..."] [-x "32 64"] [-t "top ..."]
#   -n N     number of random seeds (default 3)
#   -s LIST  explicit seeds instead of random ones
#   -x LIST  XLEN values (default "32 64")
#   -t LIST  testbench tops (default: all nine)
#   WORK     scratch directory (default /tmp/riscv_regress)
# =============================================================================
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-/tmp/riscv_regress}
NSEEDS=3
SEEDS=""
XLENS="32 64"
TOPS="risc_top fetch_top decode_top execute_top mem_top writeback_top hazard_top csr_top flp_top"

while getopts "n:s:x:t:" opt; do
    case $opt in
        n) NSEEDS=$OPTARG ;;
        s) SEEDS=$OPTARG ;;
        x) XLENS=$OPTARG ;;
        t) TOPS=$OPTARG ;;
        *) sed -n '/^# Usage/,/^# ===/p' "$0"; exit 2 ;;
    esac
done
if [ -z "$SEEDS" ]; then
    for _ in $(seq "$NSEEDS"); do SEEDS="$SEEDS $(( (RANDOM << 15 | RANDOM) % 1000000 ))"; done
fi

DPI_DIR=$REPO/Verification/FPU/dpi
SPIKE_LIB=$REPO/Verification/Risc/spike/libspike_dpi   # built by Verification/Risc/spike/Makefile
RESULTS=()
FAILED=0

for xlen in $XLENS; do
    # Scratch layout mirrors the repo so the fixed ../../ paths in the TB resolve:
    # $S/{Design,Verification} -> repo, $S/Python = per-seed program, cwd $S/q/run
    S=$WORK/x$xlen
    rm -rf "$S"
    mkdir -p "$S/q/do" "$S/q/run/logs" "$S/Python"
    ln -s "$REPO/Design" "$S/Design"
    ln -s "$REPO/Verification" "$S/Verification"
    sed "s/vlog -work work/vlog -work work +define+XLEN=$xlen/" "$REPO/Questa/do/compile.do" > "$S/q/do/compile.do"

    cd "$S/q/run" || exit 1
    echo "[XLEN=$xlen] compiling..."
    vsim -c -do "do ../do/compile.do; quit -f" </dev/null > logs/compile.log 2>&1
    if grep -q "^\*\* Error\|Errors: [1-9]" logs/compile.log; then
        grep -m10 "Error" logs/compile.log
        RESULTS+=("$(printf '%-5s %-8s %-14s %-5s %s' "$xlen" "-" "compile" "FAIL" "see $S/q/run/logs/compile.log")")
        FAILED=1
        continue
    fi

    for seed in $SEEDS; do
        python3 "$REPO/Python/riscv_testcase_generator.py" --xlen "$xlen" --seed "$seed" --out-dir "$S/Python" > /dev/null || exit 1
        for top in $TOPS; do
            log=logs/$top.s$seed.log
            extra="-64"
            if [ "$top" = flp_top ] && [ -f "$DPI_DIR/libfpu_ref.so" ]; then
                export FLP_DPI_DIR=$DPI_DIR
                extra="-64 -sv_lib $DPI_DIR/libfpu_ref +FLP_DPI"
            fi
            if [ "$top" = risc_top ] && [ -f "$SPIKE_LIB.so" ]; then
                extra="-64 -sv_lib $SPIKE_LIB +SPIKE"          # Spike lock-step next to the ISS
            fi
            echo "[XLEN=$xlen seed=$seed] $top"
            # shellcheck disable=SC2086
            vsim -c $extra -voptargs=+acc "$top" +cover -sv_seed "$seed" \
                +UVM_VERBOSITY=UVM_LOW +UVM_MAX_QUIT_COUNT=100 \
                -do "onfinish stop; run -all; coverage save logs/$top.s$seed.ucdb; coverage report -summary; quit -f" \
                </dev/null > "$log" 2>&1

            errs=$(sed -n 's/^# UVM_ERROR : *\([0-9]*\)$/\1/p' "$log" | tail -1)
            fatals=$(sed -n 's/^# UVM_FATAL : *\([0-9]*\)$/\1/p' "$log" | tail -1)
            cov=$(awk '/Covergroups/ {print $NF; exit}' "$log")
            if grep -q "UVM Report Summary" "$log" && [ "${errs:-1}" = 0 ] && [ "${fatals:-1}" = 0 ]; then
                status=PASS
            else
                status=FAIL; FAILED=1
            fi
            RESULTS+=("$(printf '%-5s %-8s %-14s %-5s err=%-6s fatal=%-3s cov=%s' \
                "$xlen" "$seed" "$top" "$status" "${errs:-?}" "${fatals:-?}" "${cov:--}")")
        done
    done
done

echo
printf '%-5s %-8s %-14s %-5s %s\n' XLEN SEED TOP RESULT DETAIL
printf '%s\n' "${RESULTS[@]}"
echo
[ $FAILED = 0 ] && echo "ALL PASS" || echo "FAILURES (logs in $WORK/x<xlen>/q/run/logs)"
exit $FAILED
