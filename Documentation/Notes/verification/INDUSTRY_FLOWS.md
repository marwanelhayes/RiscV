# How leading teams verify CPU cores (primary sources)

Scope: verification *flows* and UVM *architecture* used by professional CPU teams,
with emphasis on RISC-V because that is where the flows are public. Every external
claim is linked; where a company's internal flow is not public, this file says so
instead of guessing. Companion docs: [CURRENT_ARCHITECTURE.md](CURRENT_ARCHITECTURE.md),
[COMPARISON.md](COMPARISON.md).

**What is and isn't public.** Arm, Intel, NVIDIA, SiFive and Tenstorrent do not
publish their production testbenches. What *is* public: (a) the open-source core
programmes run in the open by industry consortia and companies — OpenHW Group
(CVA6, CV32E4x), lowRISC (Ibex, OpenTitan), Western Digital/CHIPS Alliance (VeeR),
Google/CHIPS Alliance (riscv-dv); (b) peer-reviewed
papers by Arm and Intel engineers (§7); (c) industry surveys (§1). I did not find a
public primary source describing NVIDIA's, SiFive's or Tenstorrent's internal CPU DV
flow, so nothing below is attributed to them.

---

## 1. Context: the industry numbers

The 2024 Wilson Research Group / Siemens functional-verification study (n = 597):
"first-silicon success rates have declined to their lowest level in two decades,
with only 14 percent of projects achieving this milestone"; the report cites
SystemVerilog, UVM and formal as the methodologies whose adoption keeps growing
([Verification Academy, 2024 IC/ASIC trend report](https://verificationacademy.com/topics/planning-measurement-and-analysis/wrg-industry-data-and-trends/2024-siemens-eda-and-wilson-research-group-ic-asic-functional-verification-trend-report/)).
Only the summary page was read; the detailed PDF figures (effort split, formal
adoption percentages) are not quoted here because I did not read them.

## 2. Standards and methodology baseline

| Item | What it is | Source |
|---|---|---|
| IEEE 1800.2-2020 | The UVM standard (class library API) | [IEEE SA 1800.2-2020](https://standards.ieee.org/ieee/1800.2/7567/) |
| Accellera UVM | Reference implementation + user guide (UVM 1.2, then the 1800.2 "2017/2020" library releases) | [accellera.org UVM downloads](https://www.accellera.org/downloads/standards/uvm) |
| Siemens UVM Cookbook | De-facto style guide: agent/env/test layering, configuration objects, in-order and out-of-order scoreboards, virtual sequences, RAL integration | [Verification Academy cookbook](https://verificationacademy.com/cookbook/) |

The layered testbench the cookbook describes, and that every source below uses:
**test** (configures, selects sequences) → **env** (agents + scoreboards + coverage +
reference model) → **agents** (sequencer/driver/monitor per interface, active or
passive) → **interfaces**; stimulus via **sequences**, coordinated across agents by
**virtual sequences**; variation via the **factory** (type/instance overrides) and
**config DB**; registers via **RAL** with a **frontdoor adapter** to the bus agent.

## 3. Verification planning (vPlan / testplan) and sign-off

**OpenTitan (lowRISC)** is the most explicit public example:

- Every DUT ships "a UVM testbench, a testplan, overall DV document, a suite of
  tests, and a method to build, run tests and report the current status". The
  testplan is Hjson, machine-parsed, and used to "annotate the nightly regression
  results" so planned vs. written vs. passing tests are tracked automatically
  ([DV methodology](https://github.com/lowRISC/opentitan/blob/master/doc/contributing/dv/methodology/README.md)).
- Sign-off stages ([development_stages.md](https://github.com/lowRISC/opentitan/blob/master/doc/project_governance/development_stages.md)):
  - **V1**: DV doc + reviewed testplan; DUT with major interfaces; "All available
    interface assertion monitors hooked up"; "X / unknown checks on DUT outputs";
    smoke test; "CSR / mem test suite"; sanity and nightly regressions set up.
  - **V2**: all planned tests and covergroups written; "all assertions written and
    enabled"; nightly regression "with multiple seeds (> 90%)" passing; "90% code
    coverage across the board and 90% functional coverage".
  - **V3**: all bugs addressed, "all tests with all seeds passing", "100% code and
    100% functional coverage with waivers".
  - A parallel V0–V3 ladder exists for FPV-verified blocks (proven properties and
    COI coverage instead of simulation coverage).
- Regressions: a *sanity* suite and a *nightly* suite; nightly runs "each
  constrained random test with a sufficiently large number of seeds (arbitrarily
  chosen to be 100)", "Pass completely random seed values", "Collect and merge
  coverage", publish a testplan-annotated dashboard (same doc).
- RAL is auto-generated from the register description (`reggen`) and checked into
  the repo, with CI consistency checks (same doc, "UVM Register Abstraction Layer").

**Ibex** applies the same stages: "Ibex has achieved V2S for the opentitan
configuration, broadly this means verification almost complete (over 90% code and
functional coverage hit with over 90% regression pass rate with test plan and
coverage plan…)", with nightly results published
([Ibex verification.rst](https://github.com/lowRISC/ibex/blob/master/doc/03_reference/verification.rst)).

**OpenHW core-v-verif** separates the *Verification Plan* (features, success
criteria, coverage metrics) from the *Verification Strategy* (how the bench achieves
them), with a "Verification Planning 101" guide
([planning_requirements.rst](https://github.com/openhwgroup/core-v-verif/blob/master/docs/VerifStrat/source/planning_requirements.rst)).

## 4. UVM environment architecture for CPU cores

### 4.1 Ibex (lowRISC)

From [verification.rst](https://github.com/lowRISC/ibex/blob/master/doc/03_reference/verification.rst):

- Core-level UVM bench `dv/uvm/core_ibex`. Stimulus = **compiled programs from
  riscv-dv**, loaded into one unified memory model.
- **Two memory-interface agents** (instruction fetch, LSU) running *slave*
  (responder) sequences that grant requests — the core is the master; the TB is the
  memory. An **IRQ agent** drives random interrupts; tests drive debug requests.
- Test library extends `core_ibex_base_test`; a test list YAML drives the regression.
- Checking evolved from end-of-test trace-log comparison against an ISS (which
  "quickly falls apart" with interrupts/debug) to **lock-step co-simulation** (§5).

### 4.2 core-v-verif (OpenHW: CV32E40P/X/S, CVA6)

From [cv32_env.rst](https://github.com/openhwgroup/core-v-verif/blob/master/docs/VerifStrat/source/cv32_env.rst)
and [corev_env.rst](https://github.com/openhwgroup/core-v-verif/blob/master/docs/VerifStrat/source/corev_env.rst):

- Naming/layers: `uvma_*` (agents), `uvme_*` (environments), `uvmt_*` (tests and
  testbench). A shared library (`lib/`) holds "the instruction generator, reference
  model, common functional coverage models, UVM Agents for clocks-and-resets,
  interrupts, status, etc.", reused across cores; core-specific parts live per core.
- Phase 1: RTL and ISS run separately; a compare script diffs results. Later phases:
  "integration of the ISS as a fully integrated component in the UVM environment and
  a **Step-and-Compare** instruction scoreboard … the Imperas ISS is used as the
  reference model to predict the status of the core's PC, GPRs and CSRs after each
  instruction is executed". "Step and compare is invaluable for debug because the RM
  and RTL are executing the same instruction in a compare cycle."
- Retirement is observed through an **RVFI agent** whose instructions feed an
  **RVVI** agent connected to the reference model (`connect_rvfi_rvvi()` in the CV32E40X
  env). RVVI is a draft open standard for "interfaces required to bring together
  several of the subsystems" of a RISC-V DV bench
  ([RVVI](https://github.com/riscv-verification/RVVI)).

### 4.3 CVA6 regression content (an application-class, Linux-capable core)

The CVA6 repo's `verif/regress/` directory shows what a Linux-class core runs:
`dv-riscv-tests.sh`, `dv-riscv-arch-test.sh`, `dv-riscv-mmu-sv32-test.sh`,
`dv-generated-tests.sh` (riscv-dv), `dv-csr-embedded-tests.sh`,
`dv-interrupt-test.sh`, `pmp_cv32a65x_tests.sh`, `dhrystone.sh`/`coremark.sh`,
smoke tests per configuration (`cv32a6_imac_sv32`, `cv64a6_imafdc_sv39`), and
`linux.sh` ([cva6/verif/regress](https://github.com/openhwgroup/cva6/tree/master/verif/regress)).
Default simulators `DV_SIMULATORS=veri-testharness,spike` — RTL on Verilator in
lock-step/compare with Spike ([CVA6 README](https://github.com/openhwgroup/cva6/blob/master/README.md)).
`linux.sh` boots a BBL+kernel image on the Verilator testbench with
`+time_out=40000000` and a post-run PC/address check
([linux.sh](https://github.com/openhwgroup/cva6/blob/master/verif/regress/linux.sh)).
CVA6 also has an FPGA emulation platform ("CORE-V-APU FPGA Emulation Platform",
"FPGA Implementation and running an OS" tutorial, CVA6 README).

### 4.4 VeeR (Western Digital → CHIPS Alliance)

The VeeR EH1 repo ships a simple testbench with directed C/asm tests runnable on
Verilator, Xcelium, VCS, Questa and Riviera
([Cores-VeeR-EH1](https://github.com/chipsalliance/Cores-VeeR-EH1)); its ISS
"Whisper" was "developed for the verification of the Veer micro-controller" and
"can also run in lock step with a Verilog simulator serving as a 'golden model'
against which an implementation is checked after each instruction"
([VeeR-ISS](https://github.com/chipsalliance/VeeR-ISS)). WD's production UVM bench is
not public.

## 5. Reference models and ISS co-simulation (step-and-compare)

| Model | Role | Source |
|---|---|---|
| **Spike** | RISC-V International's reference ISS; Ibex cosim and CVA6 use it | [riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim) |
| **Sail RISC-V** | Formal executable spec "adopted by RISC-V International"; generates emulators, docs, theorem-prover models | [sail-riscv](https://github.com/riscv/sail-riscv) |
| **ImperasDV / riscvOVPsim** | commercial reference used by OpenHW step-and-compare | core-v-verif docs (above) |
| **Whisper** | WD's lock-step ISS | VeeR-ISS (above) |

Ibex cosim, the clearest public description
([cosim.rst](https://github.com/lowRISC/ibex/blob/master/doc/03_reference/cosim.rst)):
"runs a RISC-V ISS (currently only Spike is supported) in lockstep with an Ibex
core. All instructions executed by Ibex and memory transactions generated are
checked against the behaviour of the ISS. This system supports memory errors,
interrupt and debug requests which are observed in the RTL simulation and forwarded
to the ISS so the ISS and RTL remain in sync." RVFI provides retirement info and is
"extended to provide interrupt and debug information and the value of various CSRs
that are harder to model (e.g. mcycle)". The ISS sits behind "a generic interface to
allow support of multiple ISSes".

Key design rules that follow:
1. **Retirement interface** (RVFI/RVVI) as the single contract between core and checker.
2. **RTL→ISS synchronisation** only for genuinely non-deterministic events
   (interrupt arrival, bus errors, debug, counters); everything else predicted.
3. **Memory transactions checked**, not just register writes.
4. **Third-party golden model** (Spike/Sail/Imperas) — not one written by the RTL team.

## 6. Stimulus: random instruction generators and compliance suites

| Tool | What it provides | Source |
|---|---|---|
| **riscv-dv** (Google → CHIPS Alliance) | SV/UVM random instruction generator for RV32/64IMAFDC, M/S/U modes, "Page table randomization and exception", "Privileged CSR test suite", "Trap/interrupt handling", "Test suite to stress test MMU", illegal/HINT generation, a coverage model, "Co-simulation with multiple ISS : spike, riscv-ovpsim, whisper, sail-riscv". Needs UVM 1.2; verified on VCS, Xcelium, Questa, Riviera | [riscv-dv README](https://github.com/chipsalliance/riscv-dv) |
| **riscv-tests** | self-checking per-instruction tests, `-p` (physical) and `-v` (virtual memory) environments | [riscv-tests](https://github.com/riscv-software-src/riscv-tests) |
| **riscv-arch-test (ACTs)** | "Architectural Certification Tests … are not verification tests"; ACT4 framework "replaces the deprecated riscof tool"; configuration via a UDB file; Certification Test Plan | [riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test) |
| **Benchmarks / OS boot** | CoreMark, Dhrystone, Linux (CVA6 regress) | §4.3 |

Note the explicit statement from RISC-V International: certification tests prove
conformance, not correctness of the micro-architecture — random + cosim is still
required.

## 7. Formal verification

| Who | What | Source |
|---|---|---|
| **Arm** | *ISA-Formal*: "an end-to-end framework to detect bugs in the datapath, pipeline control and forwarding/stall logic of processors"; scales via "a mechanical translation of ARM's Architecture Reference Manuals to Verilog allowing the use of commercial model-checkers"; "especially effective at finding micro-architecture specific bugs involving complex sequences of instructions"; used from 3-stage microcontrollers up to superscalar cores | Reid et al., "End-to-End Verification of ARM Processors with ISA-Formal", CAV 2016 ([paper page](https://alastairreid.github.io/papers/CAV_16/), [DOI](https://link.springer.com/chapter/10.1007/978-3-319-41540-6_3)) |
| **Intel** | Datapath FV "has been part of the established methodology for most Intel processor designs", traditionally supplementing coverage-oriented testing; for Core i7 the paper (per its title and abstract) reports FV replacing testing as the primary validation method of the execution cluster. My fetch of the abstract was truncated after the first sentence, so the scope of "replacing" is not quoted here | Kaivola et al., CAV 2009 ([DOI 10.1007/978-3-642-02658-4_32](https://doi.org/10.1007/978-3-642-02658-4_32)) |
| **lowRISC Ibex** | "End-to-End Formal Verification of Ibex Trace Equivalence against the Sail Model", run with Cadence Jasper in batch mode "meant for regressions" | [ibex/dv/formal/README.md](https://github.com/lowRISC/ibex/blob/master/dv/formal/README.md) |
| **riscv-formal** (YosysHQ) | processor-independent formal ISA model + per-core formal testbenches over **RVFI**; "Sequential equivalence check can be used to prove equivalence of the processor versions with and without RVFI" | [riscv-formal](https://github.com/YosysHQ/riscv-formal), [RVFI spec](https://github.com/YosysHQ/riscv-formal/blob/main/docs/source/rvfi.rst) |
| **OpenTitan** | FPV sign-off track; assertion monitors written for FPV are reused in UVM sims; DV assertions live in SV interfaces bound to the DUT | [development_stages.md](https://github.com/lowRISC/opentitan/blob/master/doc/project_governance/development_stages.md), [DV methodology](https://github.com/lowRISC/opentitan/blob/master/doc/contributing/dv/methodology/README.md) |

Typical split used by these teams: FPV on control-heavy blocks with crisp specs
(decoders, PMP, CSR legality, arbiters, FIFOs, protocol checkers), ISA-level formal
(ISA-Formal / riscv-formal / Sail trace equivalence) on the pipeline, simulation for
everything with deep state (caches, MMU, OS boot), and equivalence checking for
netlist/RTL transformations.

## 8. Emulation, FPGA prototyping, and "boot Linux" as a test

- CVA6: Linux boot in Verilator as a regression script with a cycle timeout
  (`linux.sh`), plus an FPGA platform for OS runs (§4.3).
- Commercial emulators (Cadence Palladium, Siemens Veloce, Synopsys ZeBu) are the
  standard way large teams run OS boots pre-silicon; I did not read a primary
  vendor source for this audit, so no performance numbers are given.
- The general pattern: *simulation* for block/core DV with full checking,
  *Verilator/FPGA/emulation* for software-scale workloads with lighter checking
  (signature/console/trace-compare against an ISS run of the same image).

## 9. CI and regression infrastructure

- OpenTitan: `dvsim` drives builds/runs/coverage across simulators, nightly with
  100 random seeds per test, LSF farm, merged coverage, testplan-annotated dashboard;
  sanity suite as the quick check for shared-code changes (DV methodology, §3).
- Ibex: nightly regression with published HTML report and coverage summary
  (verification.rst, §3).
- CVA6: shell-scripted regressions under `verif/regress/` driven by a Python runner
  (`cva6.py`) with target/ISS/test-list arguments (§4.3).

## 10. Summary — the "first-grade" CPU DV stack

1. **Plan**: machine-readable testplan + coverage plan, tracked against regression
   results; staged sign-off (V1/V2/V3) with numeric gates.
2. **Bench**: layered UVM; agents per external interface (memory as responder
   agents, IRQ/debug agents); reusable library across cores.
3. **Check**: lock-step step-and-compare against a third-party golden ISS through a
   standard retirement interface; RTL→ISS sync only for non-deterministic events;
   SVA on interfaces and invariants; X-checks on outputs.
4. **Stimulus**: riscv-dv (or equivalent) random programs + directed + riscv-tests +
   ACTs, all compiled with the real toolchain.
5. **Measure**: functional coverage at ISA level (instruction/operand/hazard/trap
   crosses) and at block level; code coverage; merged across seeds.
6. **Prove**: FPV for control blocks; ISA-level formal or trace equivalence for the
   pipeline.
7. **Scale**: Verilator/FPGA/emulation for OS boot as a regression item.
8. **Automate**: nightly regressions with hundreds of seeds, dashboards, CI sanity.
