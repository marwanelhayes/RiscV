#!/usr/bin/env bash
# =============================================================================
# regress.sh
# -----------------------------------------------------------------------------
# Headless regression: every testbench top x every XLEN x N random seeds,
# optionally compliance or directed FENCE.I programs on risc_top, then one PASS/FAIL
# table and the merged functional coverage. Exit status is 0 only if every run
# passes.
#
# Per XLEN the sources are compiled once (compile.do with XLEN set) and every
# top is optimised once (vopt); the simulations then only read the library, so
# up to JOBS of them run in parallel (each in its own directory). Per seed a fresh random program is generated
# with the same seed that drives -sv_seed, so a failing row is reproduced
# exactly with: regress.sh -x <xlen> -s <seed> -t <top>
#
# A run passes when it reaches the UVM report summary with 0 UVM_ERROR and
# 0 UVM_FATAL. Per XLEN, the UCDBs of all runs are merged into merged.ucdb and
# summarised in coverage.txt (one line per covergroup type).
#
# Layout of $WORK/x<xlen>:
#   run/            work library, logs/ (one log + UCDB per run), jobs/<run>/ (sim cwd)
#   prog/s<seed>/   program of each seed (fetch_top, risc_top)
#   compliance/     compliance program directories (-c or -f)
#   merged.ucdb     all runs merged; coverage.txt its per-covergroup summary
#
# Usage: Scripts/regress.sh [-n N] [-s "seed ..."] [-x "32 64"] [-t "top ..."] [-c|-f]
#   -n N     number of random seeds (default 3)
#   -s LIST  explicit seeds instead of random ones
#   -x LIST  XLEN values (default "32 64")
#   -t LIST  testbench tops (default: all nine; -t "" runs none)
#   -c       also run the riscv-tests compliance suite (Program/build_tests.py)
#   -f       run just the two FENCE.I tests from that suite
#   WORK     scratch directory (default <repo>/Scratch; deleted at the start of every run)
#   JOBS     parallel simulations (default 12; each needs ~250 MB RAM)
# =============================================================================
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$REPO/Scratch}
JOBS=${JOBS:-12}
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
ROWS=()        # result rows in print order: a row text, or @<file> a job writes
COVERAGE=()
FAILED=0
NOSPIKE=""     # " NOSPIKE" on a row that wanted Spike lock-step but ran ISS-only
SPIKE_WARN="WARN: $SPIKE_LIB.so missing: rows marked NOSPIKE ran ISS-only (build: make -C Verification/Risc/spike)"
[ -f "$SPIKE_LIB.so" ] || echo "$SPIKE_WARN"

# run_one <xlen> <seed> <top> <name> [vsim args...]: one simulation of the
# optimised <top>_opt in jobs/<name>/ (own transcript), result row in logs/<name>.row
run_one() {
    local xlen=$1 seed=$2 top=$3 name=$4; shift 4
    local log=$PWD/logs/$name.log errs fatals cov status
    mkdir -p "jobs/$name" && ln -s ../../work "jobs/$name/work"
    (cd "jobs/$name" && vsim -c -64 "$@" "${top}_opt" -sv_seed "$seed" \
        +UVM_VERBOSITY=UVM_LOW +UVM_MAX_QUIT_COUNT=100 \
        -do "onfinish stop; run -all; coverage save ../../logs/$name.ucdb; coverage report -summary; quit -f" \
        </dev/null > "$log" 2>&1)

    errs=$(sed -n 's/^# UVM_ERROR : *\([0-9]*\)$/\1/p' "$log" | tail -1)
    fatals=$(sed -n 's/^# UVM_FATAL : *\([0-9]*\)$/\1/p' "$log" | tail -1)
    cov=$(awk '/Covergroups/ {print $NF; exit}' "$log")
    if grep -q "UVM Report Summary" "$log" && [ "${errs:-1}" = 0 ] && [ "${fatals:-1}" = 0 ]; then
        status=PASS
    else
        status=FAIL
    fi
    printf '%-5s %-8s %-24s %-5s err=%-6s fatal=%-3s cov=%s%s\n' \
        "$xlen" "$seed" "$name" "$status" "${errs:-?}" "${fatals:-?}" "${cov:--}" "$NOSPIKE" > "logs/$name.row"
}

# launch <run_one args...>: run_one in the background, at most JOBS at a time
launch() {
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
    ROWS+=("@$PWD/logs/$4.row")
    run_one "$@" &
}

# vopt_tops <top...>: optimise each top once (+acc; PROGRAM_DIR left
# overridable with -g at vsim time)
vopt_tops() {
    local top
    for top in "$@"; do
        vopt -64 +acc +floatparameters "$top" -o "${top}_opt" </dev/null > "logs/vopt_$top.log" 2>&1 ||
            { ROWS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "vopt $top" "FAIL" "see $PWD/logs/vopt_$top.log")"); FAILED=1; }
    done
}

# Every run starts from an empty scratch area: no stale library, program or UCDB
rm -rf "${WORK:?}"
for xlen in $XLENS; do
    S=$WORK/x$xlen
    mkdir -p "$S/run/logs" "$S/prog"
    cd "$S/run" || exit 1

    echo "[XLEN=$xlen] compiling..."
    vsim -c -do "set XLEN $xlen; do $REPO/Scripts/compile.do; quit -f" </dev/null > logs/compile.log 2>&1
    if grep -q "^\*\* Error\|Errors: [1-9]" logs/compile.log; then
        grep -m10 "Error" logs/compile.log
        ROWS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "compile" "FAIL" "see $S/run/logs/compile.log")")
        FAILED=1
        continue
    fi
    vtops=$TOPS
    [ $COMPLIANCE = 1 ] || [ $FENCE_I = 1 ] && [[ " $TOPS " != *" risc_top "* ]] && vtops="$vtops risc_top"
    vopt_tops $vtops

    # ── Random programs and unit environments ───────────────────────────────
    if [ -n "$TOPS" ]; then
        for seed in $SEEDS; do
            prog=$S/prog/s$seed; mkdir -p "$prog"
            python3 "$REPO/Program/riscv_testcase_generator.py" --xlen "$xlen" --seed "$seed" --out-dir "$prog" > /dev/null || exit 1
            for top in $TOPS; do
                extra=(); NOSPIKE=""
                case $top in
                    fetch_top) extra=(-gPROGRAM_DIR="$prog") ;;
                    risc_top)  extra=(-gPROGRAM_DIR="$prog")
                               if [ -f "$SPIKE_LIB.so" ]; then extra+=(-sv_lib "$SPIKE_LIB" +SPIKE)   # Spike lock-step next to the ISS
                               else NOSPIKE=" NOSPIKE"; fi ;;
                    flp_top)   if [ -f "$DPI_DIR/libfpu_ref.so" ]; then
                                   export FLP_DPI_DIR=$REPO/Program
                                   extra=(-sv_lib "$DPI_DIR/libfpu_ref" +FLP_DPI)
                               fi ;;
                esac
                echo "[XLEN=$xlen seed=$seed] $top"
                launch "$xlen" "$seed" "$top" "$top.s$seed" "${extra[@]}"
            done
        done
    fi

    # ── Compliance programs on risc_top (SV ISS lock-step) ────────────────────
    if [ $COMPLIANCE = 1 ] || [ $FENCE_I = 1 ]; then
        selection=()
        [ $COMPLIANCE = 0 ] && selection=(--fence-i)
        echo "[XLEN=$xlen] building compliance programs..."
        if ! python3 "$REPO/Program/build_tests.py" --xlen "$xlen" --out "$S/compliance" "${selection[@]}" > logs/compliance_build.log 2>&1; then
            tail -3 logs/compliance_build.log
            ROWS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "compliance build" "FAIL" "see $S/run/logs/compliance_build.log")")
            FAILED=1
        fi
        while read -r name rest; do
            if [ "$name" = SKIP ]; then
                ROWS+=("$(printf '%-5s %-8s %-24s %-5s %s' "$xlen" "-" "${rest%% *}" "SKIP" "${rest#* }")")
                continue
            fi
            echo "[XLEN=$xlen] $name"
            # Spike only on the directed privilege tests: riscv-tests use F loads/stores the ISS does not model
            extra=(); NOSPIKE=""
            if [[ $name == *priv_u_mode || $name == *priv_s_mode ]]; then
                [ -f "$SPIKE_LIB.so" ] && extra=(-sv_lib "$SPIKE_LIB" +SPIKE) || NOSPIKE=" NOSPIKE"
            fi
            launch "$xlen" 1 risc_top "$name" -gPROGRAM_DIR="$rest" +UVM_TESTNAME=risc_compliance_test "${extra[@]}"
        done < <(grep -E '^(SKIP )?rv[0-9]+' logs/compliance_build.log)
    fi
done
wait

# ── Merged functional coverage of every run of each XLEN ────────────────────
for xlen in $XLENS; do
    S=$WORK/x$xlen
    cd "$S/run" 2>/dev/null || continue
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
for row in "${ROWS[@]}"; do
    if [[ $row == @* ]]; then
        [ -f "${row#@}" ] && cat "${row#@}" || echo "missing result: ${row#@}"
    else
        echo "$row"
    fi
done | tee "$WORK/results.txt"
grep -qE '^[0-9]+ +[^ ]+ +[^ ]+ +FAIL|^missing' "$WORK/results.txt" && FAILED=1
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
