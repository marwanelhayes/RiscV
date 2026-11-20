#!/usr/bin/env bash
# =============================================================================
# regress.sh
# -----------------------------------------------------------------------------
# Headless regression: every testbench top x every XLEN x N random seeds,
# optionally compliance or directed FENCE.I programs on risc_top, then one PASS/FAIL
# table and the merged functional coverage. Exit status is 0 only if every run
# passes.
#
# Per XLEN the sources are compiled once (compile.do with XLEN set) in a
# scratch area outside the repo. Per seed a fresh random program is generated
# with the same seed that drives -sv_seed, so a failing row is reproduced
# exactly with: regress.sh -x <xlen> -s <seed> -t <top>
#
# A run passes when it reaches the UVM report summary with 0 UVM_ERROR and
# 0 UVM_FATAL. Per XLEN, the UCDBs of all runs are merged into merged.ucdb and
# summarised in coverage.txt (one line per covergroup type).
#
# Layout of $WORK/x<xlen>:
#   run/            work library, logs/ (one log + UCDB per run)
#   prog/           program of the current seed (fetch_top, risc_top)
#   compliance/     compliance program directories (-c or -f)
#   merged.ucdb     all runs merged; coverage.txt its per-covergroup summary
#
# Usage: Questa/regress.sh [-n N] [-s "seed ..."] [-x "32 64"] [-t "top ..."] [-c|-f]
#   -n N     number of random seeds (default 3)
#   -s LIST  explicit seeds instead of random ones
#   -x LIST  XLEN values (default "32 64")
#   -t LIST  testbench tops (default: all nine; -t "" runs none)
#   -c       also run the riscv-tests compliance suite (Verification/Compliance)
#   -f       run just the two FENCE.I tests from that suite
#   WORK     scratch directory (default /tmp/riscv_regress)
# =============================================================================
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-/tmp/riscv_regress}
NSEEDS=3
SEEDS=""
XLENS="32 64"
TOPS="risc_top fetch_top decode_top execute_top mem_top writeback_top hazard_top csr_top flp_top"
COMPLIANCE=0
FENCE_I=0

while getopts "n:s:x:t:cf" opt; do
    case $opt in
        n) NSEEDS=$OPTARG ;;
        s) SEEDS=$OPTARG ;;
        x) XLENS=$OPTARG ;;
        t) TOPS=$OPTARG ;;
        c) COMPLIANCE=1 ;;
        f) FENCE_I=1 ;;
        *) sed -n '/^# Usage/,/^# ===/p' "$0"; exit 2 ;;
    esac
done
if [ -z "$SEEDS" ]; then
    for _ in $(seq "$NSEEDS"); do SEEDS="$SEEDS $(( (RANDOM << 15 | RANDOM) % 1000000 ))"; done
fi

DPI_DIR=$REPO/Verification/FPU/dpi
SPIKE_LIB=$REPO/Verification/Risc/spike/libspike_dpi   # built by Verification/Risc/spike/Makefile
RESULTS=()
COVERAGE=()
FAILED=0
NOSPIKE=""     # " NOSPIKE" on a row that wanted Spike lock-step but ran ISS-only
SPIKE_WARN="WARN: $SPIKE_LIB.so missing: rows marked NOSPIKE ran ISS-only (build: make -C Verification/Risc/spike)"
[ -f "$SPIKE_LIB.so" ] || echo "$SPIKE_WARN"

# run_one <xlen> <seed> <top> <name> [vsim args...]: one simulation and its result row
run_one() {
    local xlen=$1 seed=$2 top=$3 name=$4; shift 4
    local log=logs/$name.log errs fatals cov status
    vsim -c -64 "$@" -voptargs=+acc "$top" +cover -sv_seed "$seed" \
        +UVM_VERBOSITY=UVM_LOW +UVM_MAX_QUIT_COUNT=100 \
        -do "onfinish stop; run -all; coverage save logs/$name.ucdb; coverage report -summary; quit -f" \
        </dev/null > "$log" 2>&1

    errs=$(sed -n 's/^# UVM_ERROR : *\([0-9]*\)$/\1/p' "$log" | tail -1)
    fatals=$(sed -n 's/^# UVM_FATAL : *\([0-9]*\)$/\1/p' "$log" | tail -1)
    cov=$(awk '/Covergroups/ {print $NF; exit}' "$log")
    if grep -q "UVM Report Summary" "$log" && [ "${errs:-1}" = 0 ] && [ "${fatals:-1}" = 0 ]; then
        status=PASS
    else
        status=FAIL; FAILED=1
    fi
    RESULTS+=("$(printf '%-5s %-8s %-24s %-5s err=%-6s fatal=%-3s cov=%s%s' \
        "$xlen" "$seed" "$name" "$status" "${errs:-?}" "${fatals:-?}" "${cov:--}" "$NOSPIKE")")
}

for xlen in $XLENS; do
    S=$WORK/x$xlen
    rm -rf "$S"
    mkdir -p "$S/run/logs" "$S/prog"
    cd "$S/run" || exit 1

    echo "[XLEN=$xlen] compiling..."
    vsim -c -do "set XLEN $xlen; do $REPO/Questa/do/compile.do; quit -f" </dev/null > logs/compile.log 2>&1
    if grep -q "^\*\* Error\|Errors: [1-9]" logs/compile.log; then
        grep -m10 "Error" logs/compile.log
        RESULTS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "compile" "FAIL" "see $S/run/logs/compile.log")")
        FAILED=1
        continue
    fi

    # ── Random programs and unit environments ───────────────────────────────
    if [ -n "$TOPS" ]; then
        for seed in $SEEDS; do
            python3 "$REPO/Python/riscv_testcase_generator.py" --xlen "$xlen" --seed "$seed" --out-dir "$S/prog" > /dev/null || exit 1
            for top in $TOPS; do
                extra=(); NOSPIKE=""
                case $top in
                    fetch_top) extra=(-gPROGRAM_DIR="$S/prog") ;;
                    risc_top)  extra=(-gPROGRAM_DIR="$S/prog")
                               if [ -f "$SPIKE_LIB.so" ]; then extra+=(-sv_lib "$SPIKE_LIB" +SPIKE)   # Spike lock-step next to the ISS
                               else NOSPIKE=" NOSPIKE"; fi ;;
                    flp_top)   if [ -f "$DPI_DIR/libfpu_ref.so" ]; then
                                   export FLP_DPI_DIR=$DPI_DIR
                                   extra=(-sv_lib "$DPI_DIR/libfpu_ref" +FLP_DPI)
                               fi ;;
                esac
                echo "[XLEN=$xlen seed=$seed] $top"
                run_one "$xlen" "$seed" "$top" "$top.s$seed" "${extra[@]}"
            done
        done
    fi

    # ── Compliance programs on risc_top (SV ISS lock-step) ────────────────────
    if [ $COMPLIANCE = 1 ] || [ $FENCE_I = 1 ]; then
        selection=()
        [ $COMPLIANCE = 0 ] && selection=(--fence-i)
        echo "[XLEN=$xlen] building compliance programs..."
        if ! python3 "$REPO/Verification/Compliance/build_tests.py" --xlen "$xlen" --out "$S/compliance" "${selection[@]}" > logs/compliance_build.log 2>&1; then
            tail -3 logs/compliance_build.log
            RESULTS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "compliance build" "FAIL" "see $S/run/logs/compliance_build.log")")
            FAILED=1
        fi
        while read -r name rest; do
            if [ "$name" = SKIP ]; then
                RESULTS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "${rest%% *}" "SKIP" "${rest#* }")")
                continue
            fi
            echo "[XLEN=$xlen] $name"
            # Spike only on the directed privilege test: riscv-tests use F loads/stores the ISS does not model
            extra=(); NOSPIKE=""
            if [[ $name == *priv_u_mode ]]; then
                [ -f "$SPIKE_LIB.so" ] && extra=(-sv_lib "$SPIKE_LIB" +SPIKE) || NOSPIKE=" NOSPIKE"
            fi
            run_one "$xlen" 1 risc_top "$name" -gPROGRAM_DIR="$rest" +UVM_TESTNAME=risc_compliance_test "${extra[@]}"
        done < <(grep -E '^(SKIP )?rv[0-9]+' logs/compliance_build.log)
    fi

    # ── Merged functional coverage of every run of this XLEN ────────────────
    if ls logs/*.ucdb > /dev/null 2>&1; then
        vcover merge -out "$S/merged.ucdb" logs/*.ucdb > logs/merge.log 2>&1
        vcover report -cvg "$S/merged.ucdb" 2>/dev/null | awk -v x="$xlen" '
            /^=== Instance: / { inst = $3; sub(/^\//, "", inst); sub(/_pkg$/, "", inst) }
            /^ *Covergroups /  { printf "%-5s %-24s %s\n", x, inst, $NF }' > "$S/coverage.txt"
        while read -r line; do COVERAGE+=("$line"); done < "$S/coverage.txt"
    fi
done

echo
printf '%-5s %-8s %-24s %-5s %s\n' XLEN SEED RUN RESULT DETAIL
printf '%s\n' "${RESULTS[@]}"
if [ ${#COVERAGE[@]} -gt 0 ]; then
    echo
    echo "Merged functional coverage (all runs of each XLEN: \$WORK/x<xlen>/merged.ucdb)"
    printf '%-5s %-24s %s\n' XLEN COVERGROUP COVERAGE
    printf '%s\n' "${COVERAGE[@]}"
fi
echo
[ -f "$SPIKE_LIB.so" ] || echo "$SPIKE_WARN"
[ $FAILED = 0 ] && echo "ALL PASS" || echo "FAILURES (logs in $WORK/x<xlen>/run/logs)"
exit $FAILED
