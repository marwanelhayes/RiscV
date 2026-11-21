# B4 (Supervisor mode) — handoff, 2026-11-20 21:00

Read this, then `Documentation/Notes/blocks/B4.md` in full (spec + "Implementation notes" for phase 1, phase 2a FS, and phase 2b if the 2b agent appended one).

## Rules (owner's, non-negotiable)
- Design/ edits for B4 are **approved**. Anything outside B4 under Design/ needs owner approval.
- **Never commit or push.** The owner reviews and commits.
- Minimal code, follow existing style, no unrelated refactors. XLEN 32 and 64 must both work.
- `source ~/.bashrc; export MTI_VCO_MODE=64` before any Questa run.
- `Scripts/regress.sh` uses `<repo>/Scratch` and **deletes it at start**. Never run two in one tree. Run long ones in background; wait with Monitor + until-loop (plain `sleep N; cmd` is blocked).
- Before starting: make sure no other `regress.sh` / `vsim` is running (`pgrep -fa "regress.sh|vsim -c"`). A phase-2b agent was still running its gate at handoff time.
- To only *understand* big files use `rtk bulk-read --question "..." <paths>`; read in full only before editing.

## Commands
- Usage: `Scripts/regress.sh [-n N] [-s "seed ..."] [-x "32 64"] [-t "top ..."] [-c|-f]` (`-c` = also riscv-tests compliance + directed `.S`).
- Quick: `Scripts/regress.sh -s 1234 -x 32 -t risc_top`
- Runs are parallel (`JOBS=N`, default 12, ~250 MB RAM each): each top is vopt-ed once to `<top>_opt`, each sim runs in `Scratch/x<xlen>/run/jobs/<run>/`, programs in `Scratch/x<xlen>/prog/s<seed>/`, table also in `Scratch/results.txt`. Proven equivalent to the old serial script at seed 1234 (identical rows and coverage).
- Exit gate: `Scripts/regress.sh -s "1234 1 2 3 4 5 6 7 8 9" -c`
- Results: `Scratch/x<xlen>/run/logs/<top>.s<seed>.log`, `Scratch/x<xlen>/coverage.txt`, `Scratch/x<xlen>/merged.ucdb` (`vcover report -details -cvg ... | grep ZERO`).
- Per-run interrupt count: `grep "ISS_CHK\] summary" risc_top.s*.log` ("N commits, N traps, N interrupts, N mismatches").

## Status

| Phase | Content | State |
|---|---|---|
| 1 | RTL S CSRs, delegation, SRET, irq arbitration; ISS; Spike `--priv=MSU`; commit checker; `si` suite | done, gated (3 seeds × 2 XLEN) |
| 2a | real `mstatus.FS` (reset Off, FS=Off → FP/fcsr illegal, FP write → Dirty, SD); CSR env S RAL/predictor/coverage; SVA `a_irq`, `a_trap_s` | done, gated: 54/54 tops, 0 NOSPIKE, compliance 187 PASS / 18 FAIL / 13 SKIP |
| 2b | generator S window + S handler; `Verification/Compliance/priv_s_mode.S`; coverage holes; 10-seed + 10k-interrupt gate; mutation proof | **in progress** (see below) |

Post-reboot fixes made by the parent (keep them): `Verification/Risc/csr_wr.sv` taps `FpOp`/`FpRegWrite` (without them execute_top/risc_top CSR scoreboard errored); `priv_u_mode.S` check 3 expects mstatus reset `0` / `0xA00000000` and sets FS = Initial after it.

Known compliance baseline (must stay exactly): 18 FAIL = `rv32uf`/`rv64uf` fadd fcmp fcvt_w fdiv fmadd fmin ldst recoding, `rv64uf-p-fcvt`, `rv32ui-p-ma_data` (FLW/FSW not decoded, misaligned). 13 SKIP = ld_st/st_ld/ma_data(64) code size, lrsc data size, mi breakpoint/pmpaddr, si dirty ×2, rv64si icache-alias. With `priv_s_mode` added, PASS should become 189.

## Phase 2b gate run at handoff (10 seeds, `-c`)
- XLEN 32: done. Tops 87/90 PASS. Compliance: only the known fails.
- XLEN 64: tops 90/90 PASS; compliance was at ~35/115 at 21:00.
- **Open failures (XLEN 32):**
  1. `risc_top` seeds 4 and 9: "program never reached its end (self-loop)", **0 ISS/Spike mismatches**. Seed 4: 3730 commits, 392 traps, 24 interrupts. DUT == ISS, so it is a trap storm or handler loop in the *generated program*, which points at the new generator S window/S handler (`Program/riscv_testcase_generator.py`), not the RTL. Reproduce: `Scripts/regress.sh -s 4 -x 32 -t risc_top`, then read `Scratch/x32/prog/s4/assembly1.s` (one program dir per seed) and the trap sequence. Check: the S handler re-trapping (illegal/misaligned inside handler, `sepc += 4` on an interrupt, SRET with SPP wrong), ECALL-from-S → M path, `stvec` vectored target alignment, WFI in a window with nothing to wake it.
  2. `mem_top` seed 6: `[SVA_MEMORY] MEM/WB did not capture the MEM result` @1525. B4 does not touch the memory stage, and seed 6 was never run before 2b. Likely a pre-existing seed-dependent issue: check it against HEAD (do not `git stash`/`checkout` the working tree, which holds all the uncommitted work; build a snapshot dir from `git show HEAD:<file>` copies, see the mutant recipe) before touching anything. Do not change Design/memory without owner approval (outside B4).
- **Interrupt gate far off:** 111 (x32) + 49 (x64) = **160** interrupts over 20 risc_top runs; B4 needs ≥ 10 000. ~5–12 per run. Needs denser pulses in `drive_interrupts` (`Verification/Risc/risc_test_pkg.sv`) and/or more enable windows (mie/sie/MIE/SIE set) and longer programs. Count is from `commit_checker` `interrupts`.
- csr_top coverage after 2a: 98.77% (x32) / 97.77% (x64). Unhit: `irq_cx` S-mode bins (sei/sti/ssi × deleg × enable), `wfi_cx` S/U, `trap_cx <u,c[6]>` (x32), `counter_cx <tm,1,s>` (x64). 2b worked on this; recheck the numbers in `Scratch/x*/coverage.txt`.

## Mutation proof (not yet run)
Table: B4.md "Mutation proof" (12 rows) + FS-Off mutant (delete `(FpOp && MStatusFS == 2'b00) ||` in `Design/csr_file.sv`). Each must be caught; name the catching test.

Recipe (own Scratch per copy, no clash with the repo):
```
d=<scratchpad>/mut/<name>; mkdir -p $d; cp -r Design Verification Program Scripts $d/; ln -s $PWD/ThirdParty $d/ThirdParty
sed -i '<line>s/old/new/' $d/Design/csr_file.sv; diff Design/csr_file.sv $d/Design/csr_file.sv   # must show exactly 1 intended line
$d/Scripts/regress.sh -s 1234 -x "32 64" -t "csr_top risc_top" -c
```
`sed -E` treats `(` as a group, and an earlier attempt silently matched nothing. Prefer line-number edits and always check the diff.

Already proven in 2a (x32, seed 1234): FS read stuck Dirty → caught by csr_top + risc_top; FP write doesn't set Dirty → csr_top + risc_top; FS-Off FP check removed → **csr_top only** (risc_top must catch it after the 2b generator change: FP instructions must sometimes run with FS = Off).

The 2b agent prepared snapshot dirs (`cnt_mcen cnt_scen ecall_s ens_m fs_off irq_order med_b11 med_b19 mip_base sie_noand sret_mprv sret_spp sret_tsr stval_ill tos_m wfi_u`) in the parent session's scratchpad `/tmp/claude-1000/-home-marwan-ahmed-Work-RiscV/f38f9f54-f67e-47e5-b0a9-54f3a2a8d98b/scratchpad/mut/`, but none was run. They are copies of the tree from before the gate fixes; **recreate them from the current tree** after fixing the generator.

## Remaining to finish B4
Update 2026-11-21: items 1, 2, 4 done; 3 lowered by the owner; 6 deferred to an overnight run.
1. Fix risc_top seeds 4/9 (generator), rerun those seeds. **Done** (2b generator fix; seeds 4/9 pass, 0 mismatches).
2. Triage mem_top seed 6 against HEAD; report to owner if pre-existing. **Pre-existing:** a `git archive HEAD` snapshot fails identically (`[SVA_MEMORY] MEM/WB did not capture the MEM result` @1525). Not B4; untouched pending owner approval.
3. Raise interrupt density to reach ≥ 10 000 over 10 seeds × 2 XLEN, with S-delegated, M-routed, vectored and masked cases hit. **Lowered by the owner** to ≥ 500, the count the 10-seed gate reaches (501 on 2026-11-21; B4.md line 10). `drive_interrupts`: gap 40-200 → 8-40 cycles, pulse 1-3 → 1-8 cycles (~5 → ~30 interrupts per run).
4. FS = Off FP execution in generated programs (risc_top catches the FS-Off mutant). **Done** (2b FS-Off window).
5. Full exit gate (B4.md line 10): 9 tops × 10 seeds × 2 XLEN PASS, no NOSPIKE, compliance 189 / 18 / 13, `priv_u_mode` + `priv_s_mode` pass with Spike at both XLEN.
6. Mutation proof, all 13 rows caught. **Deferred (overnight run):** `Scripts/mk_mutants.py`, recipe in B4.md "Mutation proof".
7. Append "Implementation notes (phase 2b)" to B4.md. Report to owner (files, gate counts, interrupt total, csr coverage per XLEN, mutation table, deviations). No commit.

## Files touched by B4 so far (uncommitted, plus the 2026-11-20 repo restructure in the same tree)
Design: `shared_pkg.sv csr_defs.sv csr_file.sv decode_stage.sv execute_stage.sv riscv_processor.sv`.
Verification: `CSR/*` (interface, item, predictor, reg_block, seq, subscriber, sva, top), `Risc/{riscv_iss_pkg,commit_checker,csr_wr,decode_wr,execute_wr,risc_interface,risc_test_pkg,risc_top}.sv`, `Risc/spike/spike_dpi.cc`, `Execute/*`, `Decode/*`, `Compliance/priv_u_mode.S`, new `Compliance/priv_s_mode.S`, `VPLAN.md`.
Program: `riscv_testcase_generator.py`, `build_tests.py`.
