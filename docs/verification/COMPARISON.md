# Your verification architecture vs. industry practice

Inputs: [CURRENT_ARCHITECTURE.md](CURRENT_ARCHITECTURE.md) (what the repo does,
with `file:line`) and [INDUSTRY_FLOWS.md](INDUSTRY_FLOWS.md) (what Ibex, OpenHW
core-v-verif, CVA6, OpenTitan, Arm and Intel publish, with links). This file is the
judgement. It is blunt by request.

## 1. Verdict in one paragraph

The **checking core** is closer to industry than most self-built CPU benches: a
spec-written ISS in lock-step at commit, spec-based predictors proved by mutation,
two independent FP references, and an independent LRU model in SVA. What surrounds
it is **not** industry grade: no testplan, no seeds, no regression runner, no
full-core functional coverage, a golden model written by the same person as the RTL
and never cross-checked against Spike or Sail, stimulus from one in-house generator
instead of riscv-dv + riscv-tests + ACTs, and almost no formal. The block-level envs
also spend most of the effort in the wrong place for a CPU: eight stage-level
UVM benches that check stages against a *contract emulated by the testbench*,
while the industry puts its effort into the core-level bench, where bugs between
stages actually live.

## 2. Side-by-side

| Dimension | Your repo | Ibex / core-v-verif / CVA6 / OpenTitan | Gap |
|---|---|---|---|
| Verification plan | none; status tables in DESIGN_VERIFICATION_CHANGES/COVERAGE_README | machine-readable testplan (Hjson) mapped to tests and coverage; separate vPlan vs strategy | **High** |
| Sign-off criteria | "0 errors, coverage %" per env | V1/V2/V3 with numeric gates (V2: >90 % seeds passing, 90 % code + 90 % functional; V3: 100 % with waivers) | **High** |
| Bench layering | 9 envs, 1 test + 1 sequence each, no virtual sequences, no factory overrides | test library extending a base test; directed + random tests; IRQ/debug agents; reusable agent library | Medium |
| Core-level agents | none: memories are static RTL models; IRQ pulses from the test | memory *responder agents* (randomised latency, error injection), IRQ agent | **High** — no error injection means no access-fault testing is even possible |
| Golden model | in-house ISS (`riscv_iss_pkg.sv`), same author as RTL | Spike (Ibex, CVA6), Imperas (OpenHW), Sail (Ibex formal), Whisper (VeeR) | **High** (common-mode risk; see §3.1) |
| Retirement interface | ad-hoc taps of EX/MEM/WB signals bound into the DUT (`commit_checker.sv:40-70`) | RVFI (+ `rvfi_ext`), RVVI | Medium — becomes High once commit moves to M |
| RTL→ISS sync | IRQ lines and `mcycle` value | IRQ, debug, memory errors, hard-to-model CSRs | Low (pattern is right) |
| Stimulus | one Python generator, M-mode only, 4 KiB memories | riscv-dv (M/S/U, page tables, MMU stress, CSR suites) + riscv-tests + ACTs + benchmarks + Linux | **High** |
| Compliance | none run | riscv-tests and arch tests in nightly regression (CVA6 `dv-riscv-tests.sh`, `dv-riscv-arch-test.sh`) | **High** |
| Functional coverage | per stage, good bin hygiene; **none at core level** | ISA-level coverage model (riscv-dv coverage, OpenHW common coverage), merged across seeds | **High** |
| Code coverage | collected ad hoc, no target | 90 % (V2) → 100 % with waivers (V3) | Medium |
| Assertions | 2 files (cache, AXI); none on pipeline contract | "all assertions written and enabled" at V2; X-checks on outputs at V1; protocol checkers on all interfaces | **High** |
| Formal | none | FPV on control blocks; ISA-Formal (Arm), Sail trace equivalence (Ibex), riscv-formal | **High** for PMP/decoder/CSR legality later |
| RAL | backdoor mirror of internal storage | auto-generated from register spec, frontdoor via bus, built-in CSR test suite at V1 | Low today (no bus-mapped registers yet), **High** once CLINT/PLIC/UART exist |
| Regression | manual `vsim` per env; "10 seeds" = 10 hand-regenerated programs; no `-sv_seed` | nightly, 100 random seeds per test, farm, merged coverage, dashboard; sanity suite for every change | **High** |
| Configurations | XLEN=32 only ever regressed; XLEN=64 RTL committed unregressed | one sanity test per compile-time configuration minimum (OpenTitan) | **High** (you shipped an unverified configuration) |
| Scale-out | Questa only | Verilator/FPGA for software workloads; Linux boot as a regression (CVA6 `linux.sh`) | Medium now, High at Phase 8 |
| Debug aids | last-10-commit context on mismatch | same plus trace logs, published reports | Low |

## 3. Where your approach falls short — concretely

### 3.1 The golden model is not independent

`riscv_iss_pkg.sv` says it is "written from the RISC-V specifications, NOT from the
RTL" (`:1-23`). That is the right intent, but the same engineer wrote both, from the
same reading of the spec, and the ISS also *documents implementation choices the
spec leaves open the way the core documents them* (`:13-17`). Misreadings of the spec
that are shared by both will never fail. The execute-stage predictor reuses the ISS's
CSR state (`execute_predictor_pkg.sv:14-16`), and both the ISS and the FPU predictor
use `flp_ref_pkg`, so one spec misread propagates into three checkers at once.
Every public reference flow uses a third-party model (INDUSTRY_FLOWS §5).
**Fix:** keep the ISS, but run Spike (or Sail) on the same program and diff
commit traces at least nightly; for M/S/U/MMU work, make Spike the primary
reference and the in-house ISS the fast secondary.

### 3.2 Stage-level UVM envs are the expensive part with the least payoff

Eight stand-alone envs check each stage against a contract the *testbench* emulates
(`execute_top`, `mem_top`, `fetch_top` re-implement the hazard contract,
DESIGN_VERIFICATION_CHANGES X4). Inter-stage bugs (the kind D3, D17, D32 were) only
show up when the real hazard unit and real neighbours are present — D32 was in fact
found by the execute env, but only because its TB emulates a freeze; the full-core
ISS checker is what covers the real interaction. Ibex and CVA6 put the UVM effort at
core level with memory/IRQ agents; block benches are reserved for blocks with their
own spec (FPU, caches, MMU, CSR file, PMP). **Fix:** freeze the fetch/decode/
writeback/hazard benches (keep them as regression sanity), and put all new effort
into the core-level bench and the block benches that have real specs: FPU, cache,
CSR, and later TLB/PTW/PMP/CLINT/PLIC/UART.

### 3.3 No core-level coverage means "0 mismatches" proves little

`risc_top` reports "—" for coverage (DESIGN_VERIFICATION_CHANGES §1). Zero ISS
mismatches over 10 programs says nothing about whether, say, a load-use hazard into a
JALR target followed by an interrupt was ever generated. Industry closes on an
ISA-level coverage model: instruction × operand class × hazard distance × trap/
interrupt × privilege mode. **Fix:** a coverage subscriber on the commit stream of
`commit_checker` (or the future RVFI port); cross opcodes with
`{forwarded-from-M, from-W, load-use stall, cache-miss in flight, IRQ on this commit}`.

### 3.4 Stimulus will not scale to Linux

The generator is M-mode only, targets 4 KiB memories, and cannot express page
tables, S/U transitions, delegation or MMIO. riscv-dv already does all of that
(page-table randomisation, privileged CSR suite, MMU stress) and supports
co-simulation with Spike/Sail. **Fix:** adopt riscv-dv once the toolchain flow
(PLAN_B B0.1) exists — note it needs **UVM 1.2**, while your Questa setup uses UVM
1.1d (`Questa/README.md`); budget for that migration. Keep the Python generator for
fast smoke tests.

### 3.5 No regression system, no seeds, one configuration

Industry minimum (OpenTitan): sanity suite on every change, nightly with ~100 random
seeds per test, merged coverage, one sanity test per compile-time configuration.
You have manual `vsim` calls, no `-sv_seed`, and XLEN=64 RTL that was committed
without ever being run. That last point is the most serious process failure in the
repo today: commit `3dfeb41` is titled "Added 64 bit support" and nothing proves it
works. **Fix:** a single `regress.sh` (PLAN_B already names `regress_all.sh`) that
runs every top at XLEN=32 and 64 with N random seeds and prints one table. This is a
day of work and it changes everything else.

### 3.6 Assertions are thin where CPUs break

No SVA on the pipeline contract (one stall/flush source, redirect only when EX
advances, no retirement during flush, valid-bit propagation), no X-checks on
outputs. PLAN_B §3.4 rule 5 already requires them; they are not written. Industry
V1 already requires "X / unknown checks on DUT outputs" and V2 "all assertions
written and enabled".

### 3.7 No error injection

The memory models always answer `OKAY` for data (`Design/risc_data_memory.sv:69,84`);
the only non-OKAY response is the ROM rejecting writes
(`Design/risc_instruction_memory.sv:76`). Combined with the cache's retry-forever
behaviour on errors (`Design/cache.sv:600-630`), access faults cannot be tested.
Ibex cosim explicitly forwards memory errors to the ISS.

### 3.8 Things you do better than the typical public example

- Mutation proofs that each checker can fail (DESIGN_VERIFICATION_CHANGES §3, §4).
  None of the public flows above document doing this per checker.
- Two independent FP references plus targeted binade-edge stimulus.
- The commit checker already does memory-store comparison and trap-CSR comparison,
  which Ibex's older trace-compare flow did not ("quickly falls apart" with
  interrupts — Ibex verification.rst).

## 4. Prioritised recommendations

| # | Action | Effort | Why first |
|---|---|---|---|
| 1 | `regress.sh`: all tops × {XLEN 32, 64} × N random seeds (`-sv_seed random`, generator `--seed`), one PASS/FAIL table | ~1 day | Proves the committed RV64 work; every other item is measured by it |
| 2 | Run the existing tests at XLEN=64 and fix what breaks (DESIGN_VERIFICATION_CHANGES §7 already lists `mem_ral_checker` word index) | days | An unverified configuration is in `Main` |
| 3 | RVFI-style retirement port bound from the TB (PLAN_B B0.2) and Spike lock-step next to the in-house ISS (B0.3) | ~1 week | Independent golden model; required before commit moves to M |
| 4 | `riscv-tests` (`rv32ui/um/mi`, then `ua/si`, `-v-`) and ACT4 suites in the regression (B0.4, updated from RISCOF to ACT4) | ~1 week | Third-party stimulus with self-checking results |
| 5 | Core-level ISA functional coverage on the commit stream | 2–3 days | Makes "0 mismatches" mean something |
| 6 | Memory responder agent with random latency (`axi_random_stall` exists — bind it) and error injection | 2–3 days | B1.5 exit gate; prerequisite for access faults |
| 7 | Pipeline-contract SVA + X-checks bound from the tops | 2–3 days | PLAN_B §3.4 rule 5; catches inter-stage bugs at the cycle they happen |
| 8 | Testplan file (YAML/Hjson) per feature in `docs/` with a column linking to test/coverpoint; V1/V2/V3-style gates per PLAN_B phase | ongoing | Turns the status tables into a tracked plan |
| 9 | Migrate to UVM 1.2 / IEEE 1800.2 library; adopt riscv-dv for M/S/U/MMU stimulus | 1–2 weeks | riscv-dv requires UVM 1.2 |
| 10 | Formal: FPV on `alu_decoder`/`opcode_decoder` illegal-encoding logic and, later, `pmp.sv` and `amo_unit.sv` | per block | Exhaustive where simulation is weakest |
| 11 | Frontdoor RAL + built-in register sequences for CLINT/PLIC/UART when they exist | per block | Industry V1 "CSR / mem test suite" |
| 12 | Linux boot as a nightly Verilator test with a pass criterion (UART string or finisher) | Phase 8 | CVA6 `linux.sh` model |

Stop doing: adding more stage-level UVM benches for blocks without their own spec
(fetch/decode/writeback/hazard). They cost a full 13-file env each and duplicate
what the core-level ISS checker already catches.
