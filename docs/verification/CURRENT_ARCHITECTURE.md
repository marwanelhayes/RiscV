# Current verification architecture (as it actually is)

Audited at commit `3dfeb41` on 2026-11-05, read-only. Every claim cites the repo.
Companion docs: [INDUSTRY_FLOWS.md](INDUSTRY_FLOWS.md) (what leading teams do),
[COMPARISON.md](COMPARISON.md) (gap analysis). Change history of the envs is in
[`../DESIGN_VERIFICATION_CHANGES.md`](../DESIGN_VERIFICATION_CHANGES.md); bin-level
coverage in [`../../Verification/COVERAGE_README.md`](../../Verification/COVERAGE_README.md).

## 1. Big picture

```
                  ┌──────────────── risc_top (full core) ───────────────────┐
 Python generator │ InstrMem ◀─AXI─ riscv_processor ─AXI─▶ DataMem          │
 (random program) │   ▲ $readmemb        │ bind (passive taps)               │
  binary1.txt ────┼───┘        fetch_wr decode_wr execute_wr memory_wr ...    │
  program_info ───┼─▶ risc_test    │ 6 stage envs, all UVM_PASSIVE            │
                  │                └ commit_checker ◀── riscv_iss_pkg (ISS)   │
                  │                    lock-step on every EX commit           │
                  └───────────────────────────────────────────────────────────┘

 8 stand-alone block envs (fetch, decode, execute, mem, writeback, hazard, csr, fpu):
   item ─▶ seq ─▶ sequencer ─▶ driver ─▶ vif ─▶ DUT stage ─▶ monitor ─┬▶ subscriber (covergroup)
                                                                       ├▶ predictor ─▶ expected_fifo ┐
                                                                       └▶ actual_fifo ───────────────┴▶ scoreboard (in-order compare)
   + RAL mirror/backdoor checkers (fetch, decode, csr, mem) + SVA (cache, AXI)
```

Simulator: Questa with its bundled UVM 1.1d (`Questa/README.md`, "UVM 1.1d
(bundled with Questa)").

## 2. Per-block environments

Every env follows the same 13-file layout (`*_interface.sv`, `*_item_pkg.sv`,
`*_seq_pkg.sv`, `*_driver_pkg.sv`, `*_monitor_pkg.sv`, `*_agent_pkg.sv`,
`*_predictor_pkg.sv`, `*_scoreboard_pkg.sv`, `*_subscriber_pkg.sv`,
`*_config_pkg.sv`, `*_env_pkg.sv`, `*_test_pkg.sv`, `*_top.sv`; README "Verification
Structure"). Representative wiring, from `Verification/Execute/execute_env_pkg.sv:65-69`:
monitor → subscriber, predictor and the scoreboard's actual FIFO; predictor →
expected FIFO. The scoreboard is the Verification Academy "in-order comparator"
(`Verification/Execute/execute_scoreboard_pkg.sv:1-60`, two `uvm_tlm_analysis_fifo`s,
`compare()` per pair).

| Env | DUT | Stimulus (items per run) | Reference model | Extra checkers | Func. cov. (COVERAGE_README) |
|---|---|---|---|---|---|
| Fetch | `fetch_stage` + I-cache + ROM | 10 000 (`fetch_seq_pkg.sv:29`) | predictor from contract | RAL ROM image check, `cache_sva`, `AXI_Assertions` (`fetch_top.sv:96`) | 100 % |
| Decode | `decode_stage` (+ GPR/FPR files) | 100 000 (`decode_seq_pkg.sv:24`) | predictor from ISA, RAL mirror as RF model | `decode_reg_checker` (mirror vs DUT on every WB + final sweep) | 94.84 % |
| Execute | `execute_stage` (+ FPU, CSR passive sub-envs) | 10 000 (`execute_seq_pkg.sv:24`) | ISA predictor that **reuses the ISS's CSR state and `flp_ref_pkg`** (`execute_predictor_pkg.sv:1-34`) | — | 99.37 % |
| Memory | `memory_stage` + D-cache + RAM | 10 000 and 1 000 000 (`mem_seq_pkg.sv:23,48`) | byte-exact flat-memory predictor (the compiled one is `Memory/unused/mem_flat_predictor_pkg.sv`) | RAL write-beat checker, `cache_sva` (independent true-LRU model), `AXI_Assertions` (`mem_top.sv:140`) | 100 % |
| WriteBack | `wb_stage` | 10 000 | contract predictor (redirect priority) | — | 100 % |
| Hazard | `hazard_unit` | 10 000 + 20 000 | combinational predictor from PLAN_B §3.4 (`hazard_predictor_pkg.sv:1-25`) | — | 100 % |
| CSR | `csr_file` | 10 000 | predictor + per-register RAL | `csr_reg_checker` every cycle + final sweep | 100 % |
| FPU | `risc_fpu` | 1 000 000 (`+FLP_ITEMS`, `flp_seq_pkg.sv:42-43`) | exact SV reference `flp_ref_pkg` **and** Python golden over DPI-C (`FPU/dpi/fpu_ref.c`, `fpu_golden.py`) | binade-edge injection 5 % | 91.17 % |

Structure facts across all envs:

- One test class per env (`grep "extends uvm_test"` → 9 tests total, one in each
  `*_test_pkg.sv`), one main sequence per env (10 sequence classes total), each a
  `repeat(N) randomize()` loop (e.g. `Verification/Execute/execute_seq_pkg.sv:20-31`).
- Constraints live on the item (e.g. `Verification/Execute/execute_item_pkg.sv:115-157`:
  reset probability, freeze probability, IRQ, kind distribution, forwarding, alignment).
- No virtual sequencer/sequences, no factory overrides, no `uvm_report_catcher`
  (`grep` for `p_sequencer`, `set_type_override`, `uvm_virtual_sequence`: none).
- Envs nest: `execute_env` instantiates `flp_env` and `csr_env` in passive mode
  (`execute_env_pkg.sv:41-55`).
- The stand-alone tops emulate the hazard contract around the stage
  (DESIGN_VERIFICATION_CHANGES X4), so a stage env checks the stage against the
  *contract*, not against the real hazard unit.

## 3. RAL usage

Four RAL models — fetch ROM, decode GPR/FPR, CSR, data RAM — all **mirror +
backdoor** via `uvm_hdl_read` and `add_hdl_path` (`Verification/CSR/csr_reg_block_pkg.sv:30,69`;
`Verification/Decode/decode_gpr_reg_pkg.sv:52`; `Verification/Memory/mem_reg_block_pkg.sv:26`).
There is **no frontdoor adapter and no bus-mapped register map**, because none of
these storages sits behind a register bus (README "UVM RAL"). In `risc_top` the
same models are re-rooted with `set_hdl_path_root()` (README). No RAL built-in
sequences are used (`grep uvm_reg_hw_reset_seq\|bit_bash` → none). This is RAL used
as a *scoreboard for internal state*, which is legitimate but not what RAL is
primarily for in industry (see INDUSTRY_FLOWS §4).

## 4. Full-core environment (`Verification/Risc/`)

| Element | What it does | Evidence |
|---|---|---|
| `risc_top` | core + two AXI slave memories; binds a passive wrapper into every stage and the FPU/CSR, plus `commit_checker` | `Verification/Risc/risc_top.sv:152-199` |
| `risc_test` | builds the six stage envs, all `UVM_PASSIVE`, re-roots RAL | `Verification/Risc/risc_test_pkg.sv:96-101` |
| Program | read from `Python/binary1.txt` via `INSTR_MEM_PATH`; length from `program_info.txt`; cycle budget `words × 16 + 64` | `Design/shared_pkg.sv:383`; `risc_test_pkg.sv:35-39,60-92` |
| Interrupts | random pulses on the three IRQ pins, 40–200 cycles apart | `risc_test_pkg.sv:179-186`; DESIGN_VERIFICATION_CHANGES §6 |
| End of test | `commit_checker` raises `ISS_DONE` when the ISS commits the `JAL x0,0` self-loop; test drains 64 cycles, raises `ISS_FINAL`; timeout is an error | `commit_checker.sv:234-240`; `risc_test_pkg.sv:190-209` |
| **ISS** | `riscv_iss_pkg`: RV32I/RV64I + M + Zicsr + F-subset + M-mode traps, "written from the RISC-V specifications, NOT from the RTL" | `Verification/Risc/riscv_iss_pkg.sv:1-23` |
| **Commit checker** | on every EX commit (`ValidE && !StallE`) steps the ISS once; compares PC, trap/no-trap, next PC or vector; one cycle later `mepc/mcause/mtval`; queues expected GPR/FPR writes and stores and matches them in order at WB/MEM; prints the last 10 commits on mismatch | `Verification/Risc/commit_checker.sv:120-245` |
| Non-determinism | `mcycle`/`cycle` reads: the ISS takes the DUT's value | `riscv_iss_pkg.sv:186-187`; `commit_checker.sv:205` |
| Interrupt sync | ISS is told the IRQ line state at each commit and takes the same interrupt | `commit_checker.sv:205` |

This is a genuine **step-and-compare** architecture (the same family as Ibex cosim
and core-v-verif's step-and-compare, see INDUSTRY_FLOWS §5), with a home-grown ISS
instead of Spike/Sail/ImperasDV.

## 5. Stimulus: the Python generator

`Python/riscv_testcase_generator.py` (503 lines): standard encodings for RV32/RV64 I,
M, the F subset, Zicsr, M-mode traps; layout = jump, trap handler at `0x4`, prologue,
random body with templates (forward branches, JALR, counted loops, loads/stores near a
base pointer, ECALL/EBREAK, illegal encodings, misaligned accesses), self-loop end
(`:1-25`). Illegal-encoding menu at `:322-329`; CSR lists incl. deliberately unknown
CSRs at `:39-46`. Options `--xlen --count --seed --no-interrupts --no-fp`. Output is
one program per run; "10 seeds" in the status tables means ten regenerated programs
run by hand (no script in the repo does it).

## 6. Assertions

34 `assert property`/`cover property` occurrences in the whole tree, in two files:
`Verification/Memory/cache_sva.sv` (white-box cache invariants + independent
true-LRU reference) and `Verification/Protocol/AXI_Assertions.sv` (17 protocol
asserts). `Verification/Protocol/axi_random_stall.sv` (random AXI back-pressure)
exists but is instantiated nowhere. No assertions on the pipeline contract (PLAN_B
§3.4 rule 5 asks for them).

## 7. Coverage

- Functional: one covergroup per env subscriber (`grep covergroup`), 9–43
  coverpoints/crosses each; explicit bins with `ignore_bins` rationale
  (COVERAGE_README). Per-env numbers in §2.
- Full core: **no functional coverage** — `risc_top` reports "—"
  (DESIGN_VERIFICATION_CHANGES §1). There is no ISA-level coverage model
  (instruction × operands × hazards × traps) of what the random programs actually
  exercised.
- Code coverage: `+cover` is passed in `sim_fpu.do` and in the headless recipe; no
  code-coverage targets or merged reports are tracked.

## 8. Regression flow

- `Questa/do/compile.do` + one `sim_<env>.do` per env; GUI or `vsim -c` batch
  (`Questa/README.md`).
- No regression runner, no seed sweep (`grep sv_seed Questa/do/*.do` → none), no
  pass/fail table, no CI. XLEN is chosen by `+define+XLEN=64` but no script runs
  the 64-bit build (`Design/shared_pkg.sv:15-18`; `compile.do`).
- Mutation testing has been used **manually** to prove checkers can fail
  (e.g. WB-first forwarding → 675 ISS errors; LB zero-extend → 70 478 mismatches;
  DESIGN_VERIFICATION_CHANGES §3.5–3.7). Good practice, but it is not automated or
  re-run when the checkers change.

## 9. Strengths worth keeping

1. Spec-written ISS + commit-level lock-step at full-core level.
2. Two independent FP references (exact SV and Python), with targeted edge injection
   that found a 1-in-277k rounding bug (D33).
3. Predictors rewritten from the spec rather than copied from RTL (V1 fixed), and
   proved by mutation.
4. Independent LRU reference in SVA.
5. Uniform, documented env structure and naming.
