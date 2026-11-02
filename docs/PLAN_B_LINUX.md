# Plan B — Boot MMU Linux on the RiscV 5-Stage Core

> **Target:** `rv32ima_zicsr_zifencei_zicntr` + Sv32 + M/S/U + PMP, running
> OpenSBI (`PLATFORM=generic`, `FW_PAYLOAD`) → Linux (S-mode) → BusyBox shell
> on a 16550 UART.
>
> **Success criterion:** `Run /init as init process` followed by a BusyBox
> `#` prompt on the simulated UART console.
>
> **Scope note:** the first Linux target is RV32 (Sv32), but the core is
> **parameterized for XLEN = 32 or 64** from Phase 1 on (`DATA_WIDTH` = XLEN).
> Every later block must keep *both* widths green in regression, so RV64/Sv39
> Linux (B9.5) becomes an MMU block, not a datapath rewrite.
> [Appendix A](#appendix-a--why-data_width--64-was-broken) lists what broke the
> 64-bit flip and where each item is fixed.
>
> **Order of work (decided 2026-10-22):** Phase 1 comes first. Its rule is
> *fix what is wrong, add nothing new*: the RTL and the verification
> environment are made correct for the ISA the core already claims, at both
> XLENs, before any Linux feature (A, S/U, MMU, PMP, SoC) is started.
>
> **Extensions that stay or are planned although Linux does not need them:**
> - **F (FPU)** stays in the design as an addition. Linux is built with
>   `CONFIG_FPU=n`, but the FPU keeps working and keeps its own env.
> - **C (compressed instructions)** will be added (B9.2). Linux does not need
>   it, but it is preferable: about 25–30 % smaller code and the standard
>   `rv32imac`/`rv64imac` distro userlands.
>
> **Ground rule:** no file under `Design/` is edited without explicit owner
> approval. Each block below is a separately approved change set.

---

## Table of contents

1. [Current-state audit](#1-current-state-audit)
2. [Target architecture](#2-target-architecture)
3. [The Unison Method — keeping new blocks identical in style and contract](#3-the-unison-method)
4. [Workflow — phases and actionable blocks](#4-workflow--phases-and-actionable-blocks)
5. [Dependency graph](#5-dependency-graph)
6. [Regression gates](#6-regression-gates)
7. [Appendix A — why `DATA_WIDTH = 64` was broken](#appendix-a--why-data_width--64-was-broken)
8. [Appendix B — Linux-visible contract checklist](#appendix-b--linux-visible-contract-checklist)
9. [Appendix C — references](#appendix-c--references)

---

## 1. Current-state audit

Audited from `Design/` (read-only) on 2026-10-21.

### 1.1 What exists and is reusable

| Area | Status | Keep / Rework |
|---|---|---|
| 5-stage pipeline skeleton (`fetch/decode/execute/memory/wb_stage`) | Working for the in-house generator's ISA dialect | **Keep** structure; fix semantics (Phase 1) |
| Integer ALU incl. RV32M (`risc_alu`, `wallace_tree`, `non_restoring_divider`) | Single-cycle, combinational | **Keep** (timing is a later concern) |
| Hazard unit: load-use stall, GPR/FPR forwarding, I/D cache-miss stall | Works but has defects (§1.3) | **Rework** (B1.5) |
| L1 I-cache / D-cache (`cache.sv`): set-assoc, true LRU, write-back/allocate, AXI4 master | Solid base, word-only | **Extend**: byte strobes, bypass, invalidate, AMO, PTW port |
| AXI4 slave memories (`risc_instruction_memory`, `risc_data_memory`) | TB-grade memories | **Keep** as RAM model behind the new interconnect |
| CSR file (M-mode subset) | 4096-entry array, M-only | **Rewrite** as explicit registers (B1.6) |
| F extension (single precision FPU, FPR file) | Exists; integration defects D6, D19, D20 | **Keep as an addition.** Fix its integration in B1.7 (blocking, in-order E-stage unit). Linux is built without F (`CONFIG_FPU=n`). |
| UVM: one env per stage + `risc_top` full-core env, RAL, SVA, coverage | All 9 tops passing as of 2026-10-20, but the predictors are cycle-level copies of the RTL (V1) | **Keep the layout**; make the predictors spec-based and add an ISA golden model to `risc_top` (B1.0) |
| Python random generator | Emits the in-house dialect (branch/JAL/JALR offsets are ×4 from PC+4; LUI/AUIPC listed as unsupported) | **Retarget** to standard encoding (B1.0/B1.2). Compliance comes from `riscv-tests`, not this generator. |

### 1.2 ISA gap vs. Linux requirement

| Requirement | Present? | Evidence |
|---|---|---|
| Standard PC-relative branch/JAL (target = **PC** + imm) | ❌ | `decode_stage.sv:330` `SignImmD << 2`, `decode_stage.sv:335` `PCPlus4D + …`. Generator divides by 4 (`riscv_testcase_generator.py:213`). |
| JALR (target = (rs1 + imm) & ~1) | ❌ | JALR uses the same `PCBranchD`, so rs1 is never used for the target |
| LUI / AUIPC | ❌ | No `U`-type opcodes in `opcode_t` (`shared_pkg.sv`); generator marks them unsupported (`:90`) |
| SLLI / SRLI / SRAI | ❌ | `alu_decoder.sv:49` I-type case has no `3'b001` / `3'b101` |
| LB/LH/LBU/LHU/SB/SH | ❌ | `memory_stage` never uses `funct3M` for extract/sign-extend; cache CPU port is word-only, with no byte enables |
| FENCE / FENCE.I (Zifencei) | ❌ | Opcode `0001111` not decoded → illegal |
| A extension (LR/SC/AMO*) | ❌ | Opcode `0101111` not decoded |
| Zicntr (`cycle`, `time`, `instret` + `*h`) | Partial | `mcycle`/`cycle` 32-bit only; no `time`, `instret`, `*h` |
| S-mode, U-mode, privilege tracking | ❌ | No privilege register; `mret` only |
| `sret`, `wfi`, `sfence.vma` | ❌ | `decode_stage.sv` recognises only MRET/ECALL/EBREAK |
| Delegation (`medeleg`/`mideleg`) | ❌ | Hardwired read-only (by design for M-only) |
| Sv32 MMU (TLB + walker), `satp` | ❌ | — |
| PMP | ❌ | — |
| Precise exceptions | ❌ | See §1.3 (EX/MEM never flushed; trap registered one cycle late) |
| CLINT (`mtime`/`mtimecmp`/`msip`) | ❌ | Interrupts are raw top-level pins |
| PLIC, UART 16550, boot ROM, address map, uncached MMIO | ❌ | Two private AXI masters straight to two memories |

### 1.3 What is wrong today (fixed in Phase 1)

Audited again on 2026-10-22 against the RISC-V Unprivileged spec (RV32I/RV64I,
M, F, Zicsr) and the Privileged spec (M-mode). The classification rule for
Phase 1 is:

> **Wrong** = the RTL accepts an instruction, CSR or parameter value that the
> core claims, and does something other than the spec says, *or* the RTL is
> missing something that the claimed base ISA makes mandatory.
> **New** = anything the core does not claim today (A, Zifencei, Zicntr `time`,
> S/U modes, MMU, PMP, CLINT/PLIC/UART, C). New things stay in Phases 2–9.

Under that rule, the gaps of the *base* ISA (LUI, AUIPC, shift-immediates,
sub-word loads/stores, FENCE, and the RV64I-only instructions once
`DATA_WIDTH = 64`) are defects, because the core reports `misa.I` and decodes
those opcode spaces. A, Zifencei, S/U, etc. are not, because the core never
claimed them.

#### 1.3.1 Design defects

| # | Sev | Where | Defect | Consequence | Fix |
|---|---|---|---|---|---|
| D1 | P0 | `decode_stage.sv:321,330,335` | Branch/JAL target = `PC+4 + (imm<<2)`; the B-immediate also drops bit 0 | No standard binary runs | B1.2 |
| D2 | P0 | decode/execute | JALR ignores rs1 | `ret` and indirect calls impossible | B1.2 |
| D3 | P0 | `hazard_unit.sv:379` + every pipeline register | A D-cache miss or a busy FPU stalls only F/D. ID/EX reloads the same instruction every cycle while EX/MEM and MEM/WB keep advancing | Instructions duplicated or lost on every miss | B1.5 |
| D4 | P0 | `memory_stage.sv:132` | `CPUReadEn(!MemWriteM)`: every non-store issues a D-cache read at `ALUOutM` | Spurious misses/refills; fatal on MMIO | B1.4 |
| D5 | P0 | `hazard_unit.sv:308` | WB forwarding is checked **before** MEM | `add x1; add x1; use x1` reads the older value | B1.5 |
| D6 | P1 | `hazard_unit.sv:352,366` | FPR forwarding skips `f0` (f0 is a real register) | Wrong FP results | B1.7 |
| D7 | P0 | `execute_stage.sv:241` | CSR write data uses un-forwarded `RD1E` | `csrw` after its producer writes a stale value | B1.5 |
| D8 | P0 | `csr_file.sv` + `wb_stage.sv` | Trap detected in EX but `TrapIsSet` is registered: the trapping instruction and one younger instruction still commit, and the CSR file re-runs the trap entry every cycle while the pipeline is stalled | Imprecise, non-restartable traps | B1.6 |
| D9 | P1 | `csr_file.sv:51` | 4096 × XLEN array written from several functions | Not synthesizable as RAM, huge at XLEN = 64, any address readable/writable | B1.6 |
| D10 | P1 | `csr_file.sv:85` | `misa = 0x4000_0100` (RV32I only) although M and F execute | Software sees the wrong ISA | B1.6 |
| D11 | P2 | `riscv_processor.sv`, `risc_control_unit.sv`, `non_restoring_divider.sv` | `StallF`, `MemWriteM`, `OverflowW…`, `FPUValidD`, `NegativeQuotient` used without declaration | Works by accident; `default_nettype none` fails | B1.8 |
| D12 | P2 | `execute_stage.sv:21,344` | `` `define VERIF`` plus `bind` inside synthesizable RTL | Verification leaks into the design | B1.8 |
| D13 | P2 | `riscv_processor.sv:26` | `ADDR_WIDTH = 8` default vs `FINAL_ADDR_WIDTH = 10` | Silent mismatch without overrides | B1.1 |
| D14 | P2 | `decode_stage.sv:166` | Passes the PC `ADDR_WIDTH` as the reg-file index width | Wrong contract | B1.1 |
| D15 | P0 | `csr_file.sv:159` | `HandleReturn` clears `TrapIsSet`, and `wb_stage` only redirects on `TrapIsSet`: **MRET never jumps to `mepc`** | Trap handlers never return | B1.6 |
| D16 | P0 | `csr_file.sv:243` | Interrupts are taken in any cycle, even on a pipeline bubble (`mepc = PCPlus4E-4 = 0xFFFF_FFFC`) | Return address garbage | B1.6 |
| D17 | P0 | `hazard_unit.sv:380` + `wb_stage.sv:278` | A taken branch in E while the I-cache misses: `StallF` blocks the PC update, but D/E are flushed and the branch leaves E | **Branch silently lost** | B1.5 |
| D18 | P0 | `execute_stage.sv:173` | MEM-stage forwarding always uses `ALUOutM`, ignoring `SelectorM` | A consumer of a JAL link value or a CSR read one instruction later gets garbage | B1.5 |
| D19 | P0 | `hazard_unit.sv:316`, `decode_stage.sv:376` | FPU→GPR results (FMV.X.W, FCVT.W.S): forwarding is selected by the *consumer's* `MoveOperationE`; the GPR write uses `FPUOutW` only if the out-of-order FPU completion happens to line up with WB | Wrong integer results after FP moves | B1.7 |
| D20 | P0 | `fpu_decoder.sv:166-186` | FEQ/FLT/FLE/FCLASS write the **FPR** `rd`; the spec writes the integer `rd` | Wrong register file updated | B1.7 |
| D21 | P1 | `opcode_decoder`, `alu_decoder`, `fpu_decoder`, `csr_file` | Illegal-instruction detection is opcode-level only: reserved funct3/funct7 (R/I-type, branch `010/011`, load/store sizes, JALR funct3), unknown SYSTEM encodings, unknown FP encodings, reserved rounding modes and unknown CSR addresses all execute silently | No illegal trap where the spec requires one | B1.3, B1.6, B1.7 |
| D22 | P0 | `memory_stage.sv` | LB/LH/LBU/LHU/SB/SH are decoded as legal but `funct3M` is never used: they behave as LW/SW (the header claims byte/half support) | Wrong data | B1.4 |
| D23 | P0 | `opcode_decoder`, `alu_decoder` | Mandatory base instructions missing: LUI, AUIPC, SLLI/SRLI/SRAI, FENCE | No compiler output runs | B1.3 |
| D24 | P1 | `execute_stage.sv:236` | `mtval` ← ALU output for **every** trap | Spec: address for misaligned, target for fetch-misaligned, 0 otherwise | B1.6 |
| D25 | P1 | `execute_stage.sv:289` | Fetch-misaligned check tests the current instruction's `PCPlus4E` instead of the taken target | Exception never raised at the right instruction | B1.2 |
| D26 | P1 | `csr_file.sv:66,209` | `mip` is a registered copy OR-ed with the live line, so an interrupt stays pending one cycle after the line drops | Spurious interrupts | B1.6 |
| D27 | P1 | `csr_file.sv` + `csr_defs.sv` | `mstatus.MPP` reads 0 instead of M (M-only core); `mstatus.FS` reads Off while the FPU executes; masks are 32-bit literals | Wrong state seen by software, wrong at XLEN = 64 | B1.6 |
| D28 | P1 | `csr_file.sv` | `mcycle` only 32-bit on RV32 (no `mcycleh`); `minstret`, `marchid`, `mimpid`, `mhpmcounter3–31` (read-zero) missing | Mandatory M-mode CSRs absent | B1.6 |
| D29 | P2 | `risc_instruction_memory.sv:73` | `$readmemb` with an absolute host path inside `Design/` | Unportable; verification data in RTL | B1.8 |
| D30 | P1 | `non_restoring_divider.sv:72` | Overflow test `dividend == (1 << (WIDTH-1))` uses a 32-bit `int` | `MIN/-1` wrong at WIDTH = 64 | B1.1 |
| D31 | P1 | `riscv_processor` … `wb_stage` | The PC is `ADDR_WIDTH` (10) bits wide | JAL/JALR link values and branch targets wrap at 1 KiB; the PC must be XLEN wide | B1.1 |

#### 1.3.2 Verification-environment defects

The environment must be able to **dissect** the design: find a wrong design
choice, not only re-check that the RTL equals itself.

| # | Where | Defect | Consequence | Fix |
|---|---|---|---|---|
| V1 | all `*_predictor_pkg.sv` | Predictors are cycle-level copies of the RTL: decode copies the ×4 branch dialect, hazard copies WB-before-MEM, decode copies FEQ→FPR, execute trusts the DUT's own forwarding selects | A design error is reproduced in the model, so it can never fail | B1.0 |
| V2 | `Verification/Risc/` | `risc_top` only re-runs the stage envs passively; there is no architectural (ISA-level) reference | D3, D8, D15–D19 are invisible at the full-core level | B1.0 (ISS commit checker) |
| V3 | `mem_predictor_pkg.sv:365-430` | Sub-word load/store semantics commented out so the predictor matches the RTL | D22 hidden on purpose | B1.0/B1.4 |
| V4 | `execute_predictor_pkg.sv:245`, `writeback_predictor_pkg.sv:102` | `$cast(exp_clone, exp)` publishes the mutable `exp` object instead of a clone | Every queued expectation aliases the latest one | B1.0 |
| V5 | decode/execute/csr predictors, CSR RAL, items | 32-bit hard-coding: `{20{…}}`, `*4`, `1 << (W-1)`, `32'h…` masks, `+32'h4` | Envs cannot run at XLEN = 64 | B1.1 |
| V6 | `Python/riscv_testcase_generator.py` | Emits the ×4 dialect, marks LUI/AUIPC unsupported, has no reference result | Stimulus and checker share the design's mistake | B1.0/B1.2 |
| V7 | `risc_test_pkg.sv` | The test stops when the PC leaves the image; there is no pass/fail signature | A run that executes garbage still "passes" | B1.0 |
| V8 | `shared_pkg.sv:362` | `INSTR_MEM_PATH` is an absolute host path | Unportable | B1.8 |
| V9 | `csr_predictor_pkg.sv` | Models the registered `TrapIsSet` and the non-returning MRET | D8/D15 encoded as expected behaviour | B1.0/B1.6 |

---

## 2. Target architecture

### 2.1 Block diagram

```
                    ┌──────────────────────────── riscv_core ───────────────────────────────┐
                    │                                                                        │
  irq_m_timer ─────▶│  F ──▶ D ──▶ E ──▶ M(commit) ──▶ W                                     │
  irq_m_soft  ─────▶│  │ITLB      ▲hazard_unit (all stall/flush)                            │
  irq_m_ext   ─────▶│  │          │                                                          │
  irq_s_ext   ─────▶│  ▼          │           ┌─────────┐   ┌──────┐                        │
  mtime[63:0] ─────▶│ ICache◀─────┼───────────│  PTW    │◀─▶│ DTLB │◀── M stage             │
                    │  │          │           └────┬────┘   └──────┘                        │
                    │  │          csr_file (M/S/U, PMP, satp, priv)                          │
                    │  │                           │                                         │
                    │  │                      DCache (+AMO, +LR/SC, +bypass)                 │
                    └──┼───────────────────────────┼─────────────────────────────────────────┘
                       │ AXI4 (I master)           │ AXI4 (D master)
                    ┌──▼───────────────────────────▼──┐
                    │        axi_interconnect         │  2 masters × N slaves, address decode
                    └─┬──────┬────────┬───────┬──────┬┘
                      │      │        │       │      │
                   BootROM  CLINT    PLIC    UART   DRAM model (risc_data_memory, ≥32 MiB)
```

### 2.2 Address map (copy of QEMU `virt`, so the DT and OpenSBI just work)

| Region | Base | Size | Cacheable (PMA) | Notes |
|---|---|---|---|---|
| Boot ROM | `0x0000_1000` | 4 KiB | yes (I) | Reset vector `0x1000`: sets `a0` = hartid, `a1` = DTB address, jumps to `0x8000_0000` |
| CLINT | `0x0200_0000` | 64 KiB | **no** | `msip` @+0x0, `mtimecmp` @+0x4000, `mtime` @+0xBFF8 |
| PLIC | `0x0C00_0000` | 64 MiB window | **no** | 2 contexts: hart0-M, hart0-S |
| UART0 (16550) | `0x1000_0000` | 256 B | **no** | `reg-shift = 0`, `clock-frequency` matches the divisor stubs |
| DRAM | `0x8000_0000` | 32–128 MiB | yes | OpenSBI @0x8000_0000, kernel @0x8040_0000 (4 MiB aligned on RV32), DTB near the top of RAM |

`ADDR_WIDTH` becomes 32 (the physical bus). The Sv32 physical space is 34 bits; Plan B caps it at 32 bits, which is legal because the extra PPN bits must then be zero, so the PTW raises an access fault if they aren't.

### 2.3 Pipeline contract (the commit point)

**Phase 1 (current core).** Every exception the core can raise today is
detected by E (illegal, ECALL/EBREAK, misaligned target, misaligned load/store
address), so E is the single commit point:

- A trap or interrupt is *taken in E, in the same cycle* (`TrapE`): the E
  instruction is squashed (it does not reach M), F/D are flushed, and the PC is
  redirected combinationally. Older instructions in M/W complete. That is
  precise. There is no registered `TrapIsSet`.
- Interrupts are taken only on a valid, non-stalled E instruction (`ValidE`),
  so `mepc` is always the PC of a real instruction.
- CSR writes, trap entry, MRET and `minstret` update only when E advances
  (`!StallE`), so stall cycles never repeat a side effect.
- Every pipeline register has `StallX`/`FlushX` (`ValidX` rides along), and
  only `hazard_unit` drives them. Any cache miss freezes the whole pipeline.

**From B5.0 on.** The MMU, PMP and bus errors add faults that are only known in
M (and in F for fetch faults). The commit point then moves to M:

- Exceptions ride down as `ExcValidX / ExcCauseX / ExcTvalX` and are taken when
  the instruction reaches M; interrupts are sampled at M.
- **Serializing instructions** (`CSR*`, `MRET`, `SRET`, `WFI`, `SFENCE.VMA`,
  `FENCE.I`, `ECALL`, `EBREAK`) execute their side effects at M; the hazard unit
  then flushes F/D/E and refetches from `PC+4` (or the trap target).
- `PCX` (not just `PCPlus4X`) is carried down to M for `mepc/sepc`.

---

## 3. The Unison Method

The goal is that a reviewer cannot tell which blocks are new. Every block in §4 must satisfy all of the rules below before its approval request is opened.

### 3.1 Naming

| Rule | Example (existing) | Apply to new code as |
|---|---|---|
| Pipeline-stage suffix `F/D/E/M/W` on every stage-crossing signal | `RegWriteE`, `RdM`, `PCPlus4W` | `PrivModeM`, `ExcCauseE`, `VAddrM`, `PageFaultM` |
| CamelCase signals, enum values per the existing enum style | `MemWriteE`, `ALUToReg` | `AmoOpE`, `SupervisorMode` |
| Module names `snake_case`, instance names CamelCase or short caps | `hazard_unit Hazard`, `cache ICache` | `tlb ITLB`, `ptw PTW`, `clint Clint` |
| AXI ports: `MAW* MW* MB* MAR* MR*` (master), same names on slaves | `cache.sv`, `risc_data_memory.sv` | `clint.sv`, `uart_16550.sv`, `plic.sv`, `axi_interconnect.sv` |
| Prefix `I`/`D` when a top has two masters | `IMARAddr`, `DMARAddr` | `PTW` shares the D master, so no new prefix |
| Opcodes, CSR addresses, causes, enums live in **`shared_pkg.sv`** only | `opcode_t`, `csr_index_t`, `traps_t` | Add `LUI`, `AUIPC`, `MISC_MEM`, `AMO` to `opcode_t`; S-mode and PMP CSRs to `csr_index_t`; new `priv_mode_t`, `amo_op_t`, `exc_cause_t` |
| Bit masks and bit positions live in **`csr_defs.sv`** only | `` `MIE``, `` `mstatus_mask`` | `` `SIE``, `` `SPP``, `` `SUM``, `` `MXR``, `` `MPRV``, `` `sstatus_mask`` |

`traps_t` (one-hot, 12 bits) is kept for the existing CSR UVM env. Add `exc_cause_t` (binary `mcause` encoding, `logic [4:0]`, which covers causes 12/13/15). The pipeline uses `exc_cause_t`; a one-line conversion feeds anything still on `traps_t` until the CSR env is migrated (B3.1).

### 3.2 Module template (copy for every new file)

```systemverilog
// =============================================================================
// <file>.sv
// -----------------------------------------------------------------------------
// <One-sentence purpose.>
//
// Responsibilities:
//   - <bullet>
//   - <bullet>
//
// Instantiates:
//   - <submodule>: <role>
// =============================================================================
import shared_pkg::*;

module <name>
#(
    parameter int DATA_WIDTH = 32,      // XLEN, passed down from riscv_processor
    parameter int ADDR_WIDTH = 32       // Physical address width
)
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,                          // Active-low async (matches every module)

    // ── <Group> ─────────────────────────────────────────────────────────────────
    input  logic [DATA_WIDTH-1:0] <Sig>X,    // <one-phrase comment>
    output logic                  <Sig>X     // <one-phrase comment>
);

    // ─── Internal wires – <group> ─────────────────────────────────────────────
    logic <...>;

    // ─── <name>: <submodule role> ─────────────────────────────────────────────
    <sub> #(.DATA_WIDTH(DATA_WIDTH)) <Inst>
    (
        .port(signal)                   // Explicit connections only, no .*
    );

    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            <reg> <= '0;                // Cleared on reset
        end
        else if (Flush<X>)
        begin
            <reg> <= '0;                // Bubble
        end
        else if (!Stall<X>)
        begin
            <reg> <= <next>;
        end
    end

    always_comb
    begin
        <defaults first, then case/if>
    end

endmodule
```

Hard rules:

- `always_ff` / `always_comb` only. Every `always_comb` assigns defaults first. No latches.
- Reset is `rst` active-low async, `if (!rst)`.
- `begin`/`end` go on their own lines, as in the existing code.
- Explicit `.port(signal)`. Use `.*` only in verification `bind`.
- No `` `define`` / `bind` / `$display` in `Design/`. Verification hooks go in `Verification/<Env>/*_wr.sv` and are bound from the TB top (the fix for D12).
- Every new file is listed in `Questa/do/compile.do` in the matching section (packages → stages → control → ALU → regfiles → memory → CSR → MMU → SoC).

### 3.3 XLEN-clean rules (enforced from B1.1; both widths regressed)

| Don't | Do |
|---|---|
| PC / branch target / link value `[ADDR_WIDTH-1:0]` | `[DATA_WIDTH-1:0]` (PC is XLEN wide); only the cache/AXI side uses `PC[ADDR_WIDTH-1:0]` |
| FPR file and FPU operands `[DATA_WIDTH-1:0]` | `[FLEN-1:0]` (`FINAL_FLP_WIDTH`); FP→integer results are sign-extended to XLEN |
| `{{20{InstructionD[31]}}, InstructionD[31:20]}` | `{{(DATA_WIDTH-12){InstructionD[31]}}, InstructionD[31:20]}` |
| `32'b0`, `32'd7`, `{27'b0, Rs}` | `'0`, `DATA_WIDTH'(7)`, `DATA_WIDTH'(Rs)` |
| `logic [DATA_WIDTH-1:0] InstructionD` | `logic [INSTR_WIDTH-1:0] InstructionD` (new `INSTR_WIDTH = 32` in `shared_pkg`). Instructions stay 32-bit at any XLEN. |
| `addr[ADDR_WIDTH-1:2]` word index | `addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH/8)]` |
| Hard 4-lane split `DATA_WIDTH/4` in `risc_reg_file` | One flat array (byte lanes add nothing for a GPR file) |
| Separate code paths for RV32/RV64 | `localparam bit IS_RV64 = (DATA_WIDTH == 64);` and a `generate if` only where the ISA differs (`*W` ops, `LD/SD`, `satp` layout, `*h` counters) |

### 3.4 Pipeline-control contract

1. **Only `hazard_unit` computes stalls and flushes.** A new block exposes a *request* (`ITLBMissF`, `PTWBusy`, `AmoBusyM`, `SerializeE`, `TrapTakenM`) and `hazard_unit` turns it into `StallF/D/E/M/W` and `FlushD/E/M/W`.
2. A stall at stage X freezes X and everything older-in-front (F…X); X+1 receives a bubble. A memory-side miss stalls **all** stages (fixes D3).
3. The forwarding priority is always youngest-producer-first (MEM before WB; fixes D5).
4. New operand consumers (CSR write data, AMO data, store data) take the **forwarded** operand, never the raw `RDxE` (fixes D7).
5. Each rule above is captured as an SVA property in `Verification/Hazard/` before the RTL change lands.

### 3.5 Interface contract for memory-side blocks

- **CPU ↔ cache** port grows once (B1.4/B1.5/B2.1/B5.3) and keeps the existing names:
  `CPUAddr, CPUWriteData, CPUWriteEn, CPUReadEn, CPUReadData, CacheHit` gain
  `CPUByteEn[DATA_WIDTH/8-1:0]`, `CPUUncached`, `CPUAmoOp`, `CPUFlushAll`, `CPUInvalidateAll`, `CPUFlushDone`.
- **Every SoC slave** (`clint`, `plic`, `uart_16550`, boot ROM) is an AXI4 slave with the *same port list* as `risc_data_memory.sv`, so `axi_interconnect` can instantiate any of them uniformly and `AXI_Assertions` binds to all of them unchanged.
- **Interrupt wires** use the stage-free names `MTimerIrq, MSoftIrq, MExtIrq, SExtIrq`. The legacy pins `TimerInterrupt/SoftwareInterrupt/ExternalInterrupt` are kept as aliases until the CSR env migrates.

### 3.6 Verification contract (mirrors the existing envs)

Each new design block `X` ships with `Verification/<X>/`:

```
<x>_interface.sv   <x>_item_pkg.sv     <x>_seq_pkg.sv      <x>_driver_pkg.sv
<x>_monitor_pkg.sv <x>_agent_pkg.sv    <x>_predictor_pkg.sv <x>_scoreboard_pkg.sv
<x>_subscriber_pkg.sv <x>_config_pkg.sv <x>_env_pkg.sv     <x>_test_pkg.sv  <x>_top.sv
<x>_reg_block_pkg.sv + <x>_reg_checker_pkg.sv   ← only if X owns architectural state (TLB: no; CLINT/PLIC/UART/CSR: yes)
<x>_sva.sv         ← protocol/invariant properties, bound from <x>_top
```

…plus:

- `Questa/do/sim_<x>.do` cloned from `sim_mem.do`, and a row in `Questa/README.md`.
- A `Verification/Risc/<x>_wr.sv` wrapper bound into `risc_top` (same pattern as `fetch_wr`, `csr_wr`).
- File-header and class-separator style per `COMMENTING_STYLE.md`.
- Coverage: one covergroup per architectural decision point, documented in `Verification/COVERAGE_README.md`.

On top of the per-block envs, three **whole-core** checkers are added once (Phase 0) and stay on for every later block:

| Checker | What it proves | Where |
|---|---|---|
| `riscv-tests` runner | ISA conformance per extension (`-p-` physical, `-v-` virtual-memory variants) | `Verification/Compliance/` |
| Spike lockstep co-simulation (RVFI → DPI) | Every retired instruction matches Spike: PC, rd write, CSR writes, trap cause/tval, memory ops | `Verification/Cosim/` |
| `riscv-arch-test` via RISCOF | Signature-based compliance incl. privileged and PMP | `Verification/Compliance/riscof/` |

### 3.7 Change gate (per block, before approval is requested)

- [ ] Block card (§3.8) filled in and checked into `docs/blocks/<ID>.md`
- [ ] Naming/template/XLEN rules (§3.1–3.3) self-reviewed
- [ ] New SVA/UVM env written **first** and failing on the old RTL where applicable (a mutation run, as was done for the LRU work)
- [ ] All existing tops pass: `fetch, decode, execute, mem, writeback, fpu, csr, hazard, risc` + every top added since
- [ ] The phase's compliance gate (§6) passes
- [ ] Spike cosim: zero mismatches on the block's directed tests and on 10 random seeds
- [ ] `PROJECT.md`, `Questa/README.md` and `Verification/COVERAGE_README.md` updated
- [ ] Explicit owner approval for the `Design/` diff

### 3.8 Block card template

```markdown
## <ID> <Title>
- Goal:            <one sentence>
- Depends on:      <IDs>
- Spec:            <document §section>
- Design files:    new: <...>   modified: <...>
- shared_pkg/csr_defs additions: <...>
- Ports added:     <module>.<port>  (stage, width, meaning)
- Hazard requests: <signal> → <stall/flush effect>
- Verification:    env <...>, SVA <...>, compliance <...>, cosim <...>
- Exit criteria:   <measurable>
- Rollback:        <how to disable/revert, e.g. parameter or git revert>
```

---

## 4. Workflow — phases and actionable blocks

Each block = one approval + one PR-sized change. Do them in order inside a phase; phases are strictly sequential except where §5 shows parallelism.

### Phase 0 — Infrastructure (no `Design/` changes)

#### B0.1 Toolchain and reference models
- **Goal:** reproducible software and reference stack.
- **Tasks:**
  - [ ] Install `riscv64-unknown-elf-gcc` (bare-metal) and `riscv32-buildroot-linux-gnu` (via Buildroot later), `dtc`, Spike (`--isa=rv32ima_zicsr_zifencei --priv=msu`), optionally Sail-RISCV.
  - [ ] Clone `riscv-tests`, `riscv-arch-test`, `opensbi`, `linux` (LTS), `buildroot` into `third_party/` (git-ignored).
  - [ ] Write `Python/elf2hex.py`: ELF → `$readmemh` image at the RAM base. This replaces `INSTR_MEM_PATH` usage for compliance runs.
- **Exit:** `spike --isa=rv32ima pk hello` runs, and `riscv-tests` builds for `rv32ui/um/ua/mi/si`.

#### B0.2 RVFI retirement port (verification-only bind)
- **Goal:** observe every retiring instruction without touching the RTL.
- **Tasks:**
  - [ ] `Verification/Risc/rvfi_wr.sv`, bound into `DUT.WriteBack`. It reconstructs `rvfi_valid, pc_rdata, insn, rd_addr, rd_wdata, trap, mem_addr, mem_rmask/wmask`.
  - [ ] Use the commit event of B1.0 (`ValidE` and E advancing, not squashed) as `rvfi_valid`, so RVFI and the in-house ISS checker see the same retirement stream.
- **Exit:** the RVFI trace of the existing `risc_top` test prints sensibly.

#### B0.3 Spike lockstep co-simulation
- **Goal:** the main debugging backbone.
- **Tasks:**
  - [ ] `Verification/Cosim/spike_dpi.cc`: load the same ELF into Spike; on each RVFI retire, step Spike once and compare. Model it on Ibex `cosim`.
  - [ ] Inject interrupts into Spike when the DUT takes one (`mip` sync).
  - [ ] `cosim_scoreboard` (UVM) reports the first mismatch with ±20 instructions of context.
- **Exit:** runs on the Phase 1 core with zero mismatches. Spike is a second, independent golden model next to the in-house ISS.

#### B0.4 Compliance harness
- **Tasks:**
  - [ ] `Verification/Compliance/compliance_top.sv`: `riscv_processor` + RAM model + `tohost` monitor (pass when `tohost == 1`).
  - [ ] `Questa/do/sim_compliance.do TEST=<name>` plus `run_compliance.sh` looping over a test list, emitting a pass/fail table.
- **Exit:** harness runs `rv32ui-p-simple`. Failure is expected.

### Phase 1 — Fix what is wrong, at XLEN = 32 and 64 (first)

**Rule:** no new extension, privilege mode or SoC block. Phase 1 makes the RTL
and the verification environment correct for what the core already claims
(RV32I/RV64I base, M, F as implemented, Zicsr, M-mode), and makes
`DATA_WIDTH = 64` work. Every defect in §1.3 is closed here.

Phase 1 starts before Phase 0 because its golden model (B1.0) is
self-contained and needs no external toolchain. When Phase 0 lands,
`riscv-tests` becomes an extra exit gate for Phase 1.

Each block retargets the generator, the predictors and the RAL in the same
change, so all envs stay green at both XLENs.

#### B1.0 Verification that can dissect the design (fixes V1–V4, V6, V7, V9)
- **Goal:** a checker that fails on a wrong design choice. It is written from the spec, never copied from the RTL.
- **Tasks:**
  - [ ] `Verification/Risc/riscv_iss_pkg.sv`: an instruction-set simulator written from the ISA spec (RV32I/RV64I + M + Zicsr M-mode + the F subset the FPU implements, FP arithmetic via the existing FPU reference model). It holds its own PC, GPRs, FPRs, CSRs and a memory image loaded from the same program file.
  - [ ] `Verification/Risc/commit_checker.sv`: bound into `risc_top`. On every committed instruction (E → M with `ValidE`, not squashed) it steps the ISS once and compares PC, `rd` write and value, store address/data/size, trap cause/`mepc`/`mtval`, and the next PC. Interrupts: when the DUT takes one, the ISS takes the same one. The first mismatch ends the test with ±10 instructions of context.
  - [ ] Stage predictors rewritten from the spec where they encode ISA meaning (immediates, branch targets, which register file is written, load/store byte semantics, forwarding priority, trap/CSR semantics). Implementation-only encodings (`ALUControlE`, mux selects) stay cycle-accurate.
  - [ ] Clone bug fixed (V4).
  - [ ] Generator: standard encodings, all base instructions, `tohost`-style end signature (`ecall` with `a0` = 0 for pass); `risc_test` checks the signature (V7).
  - [ ] **Mutation proof:** the new checkers are run on the *old* RTL and must fail on D1, D2, D5, D15, D18, D20 and D22 (log kept in `docs/blocks/B1.0.md`).
- **Exit:** the mutation proof above; the checker is green on the fixed RTL at both XLENs.

#### B1.1 XLEN parameterization (fixes D13, D14, D30, D31, A1–A13, V5)
- **Design:**
  - `INSTR_WIDTH = 32` in `shared_pkg`; instructions stay 32-bit at any XLEN.
  - PC, branch targets and link values are `DATA_WIDTH` wide; caches and AXI see `PC[ADDR_WIDTH-1:0]`.
  - Fetch selects the 32-bit instruction out of the `DATA_WIDTH` I-cache word by `PC[2]` when XLEN = 64.
  - Immediates sign-extend to XLEN; every literal and mux pad is `'0` or width-cast.
  - Memories and the cache index words by `$clog2(DATA_WIDTH/8)`; burst address steps use the beat size.
  - The FPR file and FPU operands are `FLEN` wide; FP→integer results sign-extend to XLEN.
  - `localparam bit IS_RV64 = (DATA_WIDTH == 64)` and `generate if` only where the ISA differs.
- **Verification:** every interface/item/predictor/RAL width from `FINAL_DATA_WIDTH`; the regression runs once with `FINAL_DATA_WIDTH = 32` and once with `64`.
- **Exit:** all tops green at both widths.

#### B1.2 Standard control-flow semantics (fixes D1, D2, D25)
- **Design:** B/J immediates per spec (bit 0 = 0); `PCBranchD = PCD + SignImmD`; JALR target `(ForwardedRs1 + imm) & ~1` computed in E; taken redirect to a target with `target[1] ≠ 0` raises instruction-address-misaligned on the branch/jump (`mtval` = target, `rd` not written).
- **Exit:** ISS checker green on branch/jump-heavy random programs; `rv32ui-p-{beq…jalr}` once Phase 0 lands.

#### B1.3 Base-ISA completion and illegal decoding (fixes D21, D23)
- **shared_pkg:** `opcode_t += LUI, AUIPC, MISC_MEM`, and on RV64 `OP_IMM_32 = 7'b001_1011`, `OP_32 = 7'b011_1011`.
- **Design:**
  - LUI (operand A forced to x0) and AUIPC (operand A = `PCE`).
  - SLLI/SRLI/SRAI (`shamt[5]` legal only on RV64).
  - FENCE = NOP (single hart, in-order, blocking caches). FENCE.I stays illegal until Zifencei (B2.0).
  - RV64 only: ADDIW, SLLIW, SRLIW, SRAIW, ADDW, SUBW, SLLW, SRLW, SRAW, MULW, DIVW, DIVUW, REMW, REMUW (32-bit op, result sign-extended).
  - Full illegal decoding: reserved funct3/funct7 in every opcode, unknown SYSTEM encodings (WFI decodes as a legal NOP), unknown CSRs (in `csr_file`).
- **Exit:** ISS checker green with random legal *and* random illegal encodings.

#### B1.4 Sub-word loads/stores and qualified requests (fixes D4, D22)
- **Design:**
  - `cache.sv` gains `CPUByteEn[DATA_WIDTH/8-1:0]`; write hits and the pending write of a write-miss merge per byte.
  - `memory_stage` aligns and sign/zero-extends loads per `funct3M` (LB/LH/LW/LBU/LHU, RV64 adds LWU/LD); store data is replicated across lanes with byte enables (SB/SH/SW, RV64 adds SD).
  - New `MemReadD/E/M`; the D-cache is accessed only when `MemReadM | MemWriteM`.
- **Verification:** `mem_predictor` byte semantics re-enabled (V3); cache SVA "unwritten bytes unchanged" and "no AXI traffic for ALU-only programs".
- **Exit:** ISS checker green with random sub-word traffic.

#### B1.5 Pipeline control (fixes D3, D5, D7, D17, D18)
- **Design:**
  - `hazard_unit` drives `StallF/D/E/M/W` and `FlushD/E/M`.
  - Any cache miss freezes **all** stages. The FPU stalls F/D/E and bubbles M. A load-use hazard stalls F/D and bubbles E.
  - A redirect from E (taken branch, jump, trap, MRET) is applied only when E advances, so it can never be lost.
  - Forwarding priority is MEM before WB. MEM forwarding uses the instruction's real result (ALU, link value or CSR read).
  - CSR write data takes the forwarded operand.
- **Verification:** Hazard predictor from the §3.4 contract; ISS checker with random AXI latency on both memories.
- **Exit:** ISS checker green on 10 seeds with random latency.

#### B1.6 Precise traps and the CSR file (fixes D8–D10, D15, D16, D24, D26–D28, V9)
- **Design:**
  - Traps are taken in E in the same cycle (§2.3). MRET redirects to `mepc`. Interrupts are taken only on a valid E instruction.
  - `csr_file` becomes explicit registers with a `case` read mux. Unknown CSR → illegal.
  - `misa` = `MXL | I | M | F`: `0x4000_1120` at RV32, `0x8000_0000_0000_1120` at RV64.
  - `mstatus.MPP` reads M. `mstatus.FS` is hardwired Dirty (with `SD`), because the FPU is always on.
  - `mip` reflects the interrupt lines directly.
  - `mtval` = address (misaligned load/store), target (misaligned fetch), 0 otherwise.
  - 64-bit `mcycle`/`minstret` (`mcycleh`/`minstreth` on RV32), with `cycle`/`instret` read aliases. `marchid`, `mimpid` and `mhpmcounter3–31`/`mhpmevent3–31` read zero.
  - `medeleg`/`mideleg` stay read-only zero (approved 2026-10-20).
- **Verification:** CSR predictor and RAL from the Privileged spec; RAL paths change from `CsrFile[idx]` to per-register paths.
- **Exit:** CSR env and RAL green; ISS checker green with random ECALL/EBREAK/illegal/misaligned traps and random interrupts.

#### B1.7 FPU integration (fixes D6, D19, D20; the FPU stays an addition)
- **Design:**
  - The FPU becomes a blocking, in-order E-stage unit: an FP instruction holds E until `done`, then moves down EX/MEM like any other instruction.
  - FP→integer results (FMV.X.W, FCVT.W[U].S, FEQ/FLT/FLE, FCLASS) travel in `ALUOutM`, so integer forwarding and write-back need no FPU special case.
  - FEQ/FLT/FLE/FCLASS write the integer `rd`.
  - `f0` is forwarded like any other FPR.
  - Unknown FP encodings and reserved rounding modes trap as illegal.
- **Not in Phase 1 (new, see B9.1):** FLW/FSW, FMADD family, `fflags` accrual (the FPU's flags are not the IEEE NV/DZ/OF/UF/NX set), D extension.
- **Exit:** FPU env green; ISS checker green on random FP/integer mixes.

#### B1.8 Hygiene (fixes D11, D12, D29, V8)
- **Design:**
  - Every implicit net declared; `` `default_nettype none`` at the top of each Design file.
  - `` `define VERIF``/`bind` removed from `execute_stage` and bound from the TB tops.
  - The instruction-memory model loads its image from a parameter or plusarg, not from an absolute path.
- **Exit:** all tops compile with `default_nettype none`; no host path under `Design/` or `shared_pkg`.

**Phase 1 exit gate:** all legacy tops plus the ISS-checked `risc_top`
green at XLEN = 32 and 64, on 10 random seeds each, with random AXI latency.

### Phase 2 — Zifencei and atomics (A extension)

#### B2.0 FENCE.I (Zifencei) — moved here from the old Phase 1
- **Design:** FENCE.I = serialize, then D-cache `CPUFlushAll` (write back dirty lines), then I-cache `CPUInvalidateAll`, then refetch at `PC+4`. The cache gets a flush FSM state in the existing `axi_state_t` style.
- **Exit:** `rv32ui-p-fence_i`; a self-modifying-code directed test passes under the ISS checker.

#### B2.1 LR/SC and AMOs
- **shared_pkg:**
  - `opcode_t += AMO = 7'b010_1111`.
  - `amo_op_t {AMO_LR, AMO_SC, AMO_SWAP, AMO_ADD, AMO_XOR, AMO_AND, AMO_OR, AMO_MIN, AMO_MAX, AMO_MINU, AMO_MAXU}`.
- **Design:**
  - New `amo_unit.sv` (combinational RMW ALU) in `memory_stage`.
  - The D-cache gets `CPUAmoOp`. A hit becomes a 2-cycle read-then-write (stall request `AmoBusyM`); a miss refills first.
  - Reservation register `{ResValid, ResAddr}` in `memory_stage`:
    - LR sets it.
    - SC succeeds iff valid and the address matches, then clears it.
    - It is cleared on any trap or xRET (`TrapTakenM | MRetM | SRetM`).
  - Misaligned AMO → store/AMO access fault (cause 7).
  - `aq/rl` ignored (single hart, in-order).
- **Verification:** new `Verification/Amo/` env (or extend Memory), plus cosim.
- **Exit:** `rv32ua-p-*` all pass.

### Phase 3 — Complete machine mode

#### B3.1 `misa` and CSR set update
- The register restructure, unknown-CSR trap and 64-bit counters are done in B1.6.
- **Design:** `misa` gains A, S, U as those blocks land: `0x4014_1121` at RV32 (A, F, I, M, S, U), MXL = 2 at RV64. `medeleg`/`mideleg` become writable in B4.1.
- **Exit:** CSR env and RAL green; `rv32mi-p-csr` passes.

#### B3.2 Privilege mode and checks
- **shared_pkg:** `priv_mode_t {UserMode = 2'b00, SupervisorMode = 2'b01, MachineMode = 2'b11}`.
- **Design:**
  - `PrivMode` register in `csr_file`, reset to M.
  - `mret` restores `mstatus.MPP` and sets MPP = U.
  - The ECALL cause depends on the mode (8/9/11).
  - CSR access check: `CsrIndex[9:8] > PrivMode` → illegal; a write to a read-only CSR → illegal (already in decode).
  - The FPU stays enabled (`mstatus.FS` hardwired Dirty since B1.6). It is an addition: Linux is built with `CONFIG_FPU=n` and never executes F instructions, and the FPU env keeps testing `risc_fpu` directly. Making FS writable (Off traps F opcodes) belongs to B9.1.
- **Exit:** `rv32mi-p-*` that need U-mode pass.

#### B3.3 Counters (Zicntr)
- **Design:**
  - 64-bit `mcycle`/`minstret` and the `cycle`/`instret` aliases exist since B1.6; this block adds `time/timeh`, which read the CLINT `mtime` input.
  - `mcounteren` gates S-mode access, `scounteren` gates U-mode access; a gated access traps illegal.
- **Exit:** directed test that `rdtime` and `rdcycle` work from U-mode with the enables set and trap with them clear; cosim clean.

#### B3.4 WFI
- **Design:** WFI is a legal NOP since B1.3. This block makes it serialize, then stall F until `(mip & mie) != 0` (ignoring global MIE), which saves sim time in the Linux idle loop.

### Phase 4 — Supervisor mode

#### B4.1 S-mode CSRs and trap delegation
- **shared_pkg:** `csr_index_t += sstatus 0x100, sie 0x104, stvec 0x105, scounteren 0x106, senvcfg 0x10A, sscratch 0x140, sepc 0x141, scause 0x142, stval 0x143, sip 0x144, satp 0x180, menvcfg 0x30A, mcounteren 0x306, minstret 0xB02, mcycleh 0xB80, minstreth 0xB82, cycleh 0xC80, time 0xC01, timeh 0xC81, instret 0xC02, instreth 0xC82, mtval 0x343` (rename `mbadaddr` → `mtval`).
- **csr_defs:** `` `SIE 1``, `` `SPIE 5``, `` `SPP 8``, `` `MPRV 17``, `` `SUM 18``, `` `MXR 19``, `` `TVM 20``, `` `TW 21``, `` `TSR 22``, `` `sstatus_mask``, `` `sie_mask = 0x222``.
- **Design:**
  - `sstatus` / `sie` / `sip` are *views* of `mstatus` / `mie` / `mip`, not separate storage.
  - `medeleg` / `mideleg` become writable (`mideleg` S-bits only).
  - Trap routing: if `PrivMode ≤ S` and the cause is delegated, the trap goes to S (`sepc`, `scause`, `stval`, `SPP`, `SPIE`, `SIE ← 0`, PC ← `stvec`); otherwise it goes to M.
  - `sret` restores `SPP` / `SIE`; `TSR` makes `sret` illegal in S.
  - `mip.STIP` / `SSIP` / `SEIP` are writable from M (OpenSBI injects the S timer this way when Sstc is absent).
- **Exit:** `rv32si-p-*` pass.

#### B4.2 Interrupt arbitration
- **Design:**
  - Priority MEI > MSI > MTI > SEI > SSI > STI.
  - An interrupt is taken if pending & enabled & (target mode > current mode, or target mode == current mode with xIE set).
  - M-level interrupts are never maskable by S.
  - Implemented as one `always_comb` in `csr_file` producing `IrqPending`, `IrqCause`, `IrqToS`.
- **Verification:** CSR env sequences across mode × delegation × enable combinations; cosim with randomized interrupt injection.
- **Exit:** cosim clean across 10k random interrupt events.

### Phase 5 — Sv32 MMU

#### B5.0 Move the commit point to M (was the old B1.8)
- **Why now:** page faults (B5.3), PMP faults (B6.1) and bus errors (B7.2) are only known in F or M, so E can no longer be the commit point (§2.3).
- **Design:**
  - Carry `ExcValidX`, `ExcCauseX` (`exc_cause_t`), `ExcTvalX` and `PCX` through every pipeline register.
  - Take traps and interrupts at M: `TrapTakenM` flushes F/D/E/M and suppresses the trapping instruction's writes.
  - CSR, MRET and ECALL/EBREAK side effects move to M. Serializing instructions flush younger instructions.
- **Verification:** CSR predictor moved to M-stage timing; the ISS checker is unchanged (architectural behaviour is identical), which is the proof that the move is behaviour-neutral.
- **Exit:** ISS checker green at both XLENs; `rv32mi-p-*` (non-S) pass.

#### B5.1 TLB (`tlb.sv`)
- **Design:**
  - Fully associative, `parameter int ENTRIES = 8`.
  - Entry fields: `{Valid, VPN[19:0], PPN[21:0], Mega, U, G, R, W, X, D, A, ASID}`.
  - Comb lookup outputs `TLBHit`, `PPN`, `Perms`; round-robin refill.
  - `Flush` input (full flush on `sfence.vma`; ASID/VA-selective flush optional).
  - Two instances: `ITLB` in `fetch_stage`, `DTLB` in `memory_stage`.
- **Verification:** `Verification/Tlb/` unit env with a random-PTE predictor.

#### B5.2 Page-table walker (`ptw.sv`)
- **Design:**
  - Shared by ITLB and DTLB (D has priority).
  - Issues reads **through the D-cache CPU port** via a mux, which keeps it coherent with kernel stores to page tables at no cost.
  - 2-level Sv32 walk:
    - Invalid PTE (`V = 0`, or `R = 0` with `W = 1`) → page fault.
    - Leaf at level 1 with `PPN[9:0] ≠ 0` → misaligned superpage → page fault.
  - **Svade**: `A = 0`, or `D = 0` on a store → page fault (no hardware A/D update).
  - PPN bits above `ADDR_WIDTH` non-zero → access fault.
  - Stall request `PTWBusy`.
- **Exit:** unit tests cover every fault rule in Privileged spec §"Virtual Address Translation Process".

#### B5.3 MMU integration
- **Design:**
  - Translation is active when `satp.MODE = 1` and (`PrivMode < M`, or `MPRV = 1` with `MPP < M` for loads and stores).
  - Fetch uses the ITLB in parallel with the I-cache index. VIPT is legal while `LINE_BYTES × SETS ≤ 4096`; add an `initial assert` in `cache.sv`.
  - Data uses the DTLB in M (address from EX).
  - Permission check: U-bit vs. mode, SUM for S → U loads and stores, MXR, execute-only pages, R/W/X per access type.
  - Faults 12/13/15 carry `tval = VA`.
  - Writing `satp` and executing `sfence.vma` are serializing and flush the pipeline, the ITLB and the DTLB.
  - `TVM = 1` makes `satp`/`sfence.vma` illegal in S.
- **shared_pkg:** `decode` recognizes SRET, WFI and SFENCE.VMA under the `CSR` (SYSTEM) opcode.
- **Exit:** `rv32ui-v-*`, `rv32um-v-*`, `rv32ua-v-*` all pass (these run under the riscv-tests virtual-memory environment); cosim clean.

### Phase 6 — PMP

#### B6.1 Physical Memory Protection
- **shared_pkg:** `pmpcfg0..3 (0x3A0–0x3A3)`, `pmpaddr0..15 (0x3B0–0x3BF)`.
- **Design:**
  - New `pmp.sv` with `parameter int ENTRIES = 16` (minimum 8 to be comfortable with OpenSBI).
  - Modes OFF/TOR/NA4/NAPOT and the L bit (locks the entry and applies it to M too).
  - Checked after translation for fetch, load, store and PTW accesses.
  - No match in S/U → fault; no match in M → allow.
  - Faults: instruction / load / store access faults 1 / 5 / 7.
  - Instances: one for fetch, one for D (shared with PTW).
- **Exit:** `rv32mi-p-*` PMP-related tests and riscv-arch-test `pmp` suite pass.

### Phase 7 — SoC and memory system

#### B7.1 `axi_interconnect.sv`
- **Design:** 2 masters (I, D) × 5 slaves, fixed-priority arbiter (D > I), address decode per §2.2, `AXI_DECERR` on holes → access fault. Same AXI port naming as `cache.sv`.
- **Verification:** `AXI_Assertions` bound on every master and slave port; random-traffic env.

#### B7.2 PMA / uncached path
- **Design:**
  - `pma.sv`: comb `Cacheable(addr)` from the §2.2 table.
  - D-cache `CPUUncached` → single-beat AXI read/write with `MWStrb` = byte enables, no allocate.
  - Instruction fetch from a non-executable region → instruction access fault.
- **Exit:** uncached accesses never allocate a line (cache SVA).

#### B7.3 CLINT (`clint.sv`)
- **Design:** AXI slave. `mtime` (64-bit, increments every `TIMEBASE_DIV` clocks; **keep `TIMEBASE_DIV` a parameter**, because the DT `timebase-frequency` must equal `clk / TIMEBASE_DIV`), `mtimecmp`, `msip`. Outputs `MTimerIrq = (mtime >= mtimecmp)`, `MSoftIrq = msip[0]`, `mtime` → `csr_file` for `time`.
- **Verification:** `Verification/Clint/` env + RAL (it owns architectural registers).

#### B7.4 Sstc (recommended, small)
- **Design:** `stimecmp` (0x14D) / `stimecmph` (0x15D) in `csr_file`; `mip.STIP = (time >= stimecmp)` when `menvcfg.STCE = 1`. This removes an SBI round-trip per timer tick, which noticeably speeds up the Linux boot in sim.

#### B7.5 UART 16550 subset (`uart_16550.sv`)
- **Design:** AXI slave, byte registers at offsets 0–7: RBR/THR, IER, IIR/FCR, LCR, MCR, LSR (THRE=1, TEMT=1, DR from the RX FIFO), MSR, SCR; DLL/DLM when `LCR.DLAB`. TX writes to a `TxByte/TxValid` output. RX comes from a TB input. IRQ = (IER.ERBFI & DR) | (IER.ETBEI & THRE).
- **Verification:** the TB prints `TxByte` with `$write` into `uart.log`. That log is the console for every later step.

#### B7.6 PLIC (`plic.sv`)
- **Design:** sources 1..N (UART = 10, as on QEMU virt), priorities, pending, per-context enable/threshold/claim/complete; context 0 → `MExtIrq`, context 1 → `SExtIrq`.
- **Note:** for the first Linux boot the UART can run in polled mode (DT without `interrupts`), so B7.6 may slip to after the first shell.

#### B7.7 Boot ROM + SoC top (`riscv_soc.sv`)
- **Design:** `riscv_soc` = `riscv_processor` + `axi_interconnect` + ROM + CLINT + PLIC + UART + RAM model. The ROM holds 5 instructions:

  ```asm
  auipc t0, 0
  csrr  a0, mhartid
  la    a1, DTB_ADDR
  li    t0, 0x80000000
  jr    t0
  ```

  Reset PC becomes a parameter, `RESET_VECTOR = 32'h0000_1000`.
- **RAM model:** for ≥32 MiB in simulation, back `risc_data_memory` with a SystemVerilog associative array (sparse) behind a `` `ifdef SIM`` in the **TB**, not in `Design/`.
- **Exit:** `riscv_soc_top` runs a bare-metal "hello" over the UART.

### Phase 8 — Software bring-up

#### B8.1 Bare-metal smoke suite (`Software/baremetal/`)
- [ ] `hello` (UART), `timer` (CLINT MTI then STI via delegation), `ecall_chain` (U → S → M), `pagefault` (S handler maps a page and retries), `amo` (spinlock), `pmp` (S denied).
- **Exit:** all pass in `riscv_soc_top`, cosim clean.

#### B8.2 Device tree (`Software/dts/riscv_soc.dts`)
```dts
/dts-v1/;
/ {
    #address-cells = <1>; #size-cells = <1>;
    compatible = "riscv-virtio"; model = "RiscV Plan-B SoC";
    chosen { bootargs = "earlycon=sbi console=ttyS0"; stdout-path = "/soc/serial@10000000"; };
    cpus {
        #address-cells = <1>; #size-cells = <0>;
        timebase-frequency = <TIMEBASE_HZ>;            /* == clk / TIMEBASE_DIV */
        cpu0: cpu@0 {
            device_type = "cpu"; reg = <0>; status = "okay";
            compatible = "riscv";
            riscv,isa-base = "rv32i";
            riscv,isa-extensions = "i", "m", "a", "zicsr", "zifencei", "zicntr", "sstc";
            mmu-type = "riscv,sv32";
            cpu0_intc: interrupt-controller { #interrupt-cells = <1>; interrupt-controller; compatible = "riscv,cpu-intc"; };
        };
    };
    memory@80000000 { device_type = "memory"; reg = <0x80000000 0x4000000>; };   /* 64 MiB */
    soc {
        #address-cells = <1>; #size-cells = <1>; compatible = "simple-bus"; ranges;
        clint@2000000 { compatible = "riscv,clint0"; reg = <0x2000000 0x10000>;
                        interrupts-extended = <&cpu0_intc 3>, <&cpu0_intc 7>; };
        plic: interrupt-controller@c000000 { compatible = "riscv,plic0"; reg = <0xc000000 0x4000000>;
                        #interrupt-cells = <1>; interrupt-controller; riscv,ndev = <31>;
                        interrupts-extended = <&cpu0_intc 11>, <&cpu0_intc 9>; };
        serial@10000000 { compatible = "ns16550a"; reg = <0x10000000 0x100>;
                        clock-frequency = <UART_CLK_HZ>; interrupt-parent = <&plic>; interrupts = <10>; };
    };
};
```
The `riscv,isa-extensions` list must name **exactly** what the RTL implements. Drop `"sstc"` if B7.4 is skipped. A lying ISA string is the most common cause of silent boot hangs.

#### B8.3 OpenSBI
- [ ] `make PLATFORM=generic PLATFORM_RISCV_XLEN=32 PLATFORM_RISCV_ISA=rv32ima_zicsr_zifencei FW_PAYLOAD=y FW_PAYLOAD_PATH=<Image> FW_FDT_PATH=<dtb> FW_TEXT_START=0x80000000`
- **Exit:** the OpenSBI banner appears in `uart.log` with `Platform HART Count: 1`, `Boot HART ISA: rv32imasu`, the PMP count, and the domain list.

#### B8.4 Linux + Buildroot
- [ ] Buildroot: `BR2_riscv`, `BR2_RISCV_32`, ISA `rv32ima` (no F/D/C for the first boot; `rv32imac` after B9.2), ABI `ilp32`, musl, BusyBox, `BR2_TARGET_ROOTFS_INITRAMFS`.
- [ ] Kernel: `rv32_defconfig`, then trim:
  - `CONFIG_FPU=n`, `CONFIG_RISCV_ISA_C=n`, `CONFIG_RISCV_ISA_ZICBOM=n`, `CONFIG_RISCV_ISA_SVPBMT=n`, `CONFIG_RISCV_ISA_V=n`.
  - `CONFIG_SERIAL_8250=y`, `CONFIG_SERIAL_8250_CONSOLE=y`, `CONFIG_SERIAL_OF_PLATFORM=y`, `CONFIG_HVC_RISCV_SBI=y`.
  - `CONFIG_SMP=n`, `CONFIG_MODULES=n`, initramfs built in.
  - Drop unused drivers to shrink the boot.
- **Exit:** `earlycon` messages through `Run /init as init process`.

#### B8.5 Simulation speed
- Linux to a shell is roughly 100M–500M instructions. Questa will take days, so:
  - [ ] Verilator build of `riscv_soc` (`Verification/Verilator/`, C++ harness with the UART console and ELF loader). The rule "no SV-only constructs in `Design/`" keeps this possible: no classes, no `bind`, no `` `define VERIF``.
  - [ ] Checkpoint: dump RAM, CSRs and GPRs at the OpenSBI → kernel handoff; restore to skip re-running firmware.
  - [ ] Optional FPGA target (Arty A7 / ECP5) through `Syn/`.
- **Exit:** BusyBox `#` prompt. 🎉

### Phase 9 — After the first shell

B9.1 and B9.2 are **committed** work (not needed by Linux, but the design
keeps them). The rest is optional.

#### B9.1 Complete the F extension (the FPU is kept as an addition)
- **Design:** FLW/FSW (FP loads/stores through the D-cache port of B1.4), the FMADD/FMSUB/FNMSUB/FNMADD family, IEEE `fflags` accrual (NV/DZ/OF/UF/NX) from the FPU, invalid dynamic `frm` → illegal, writable `mstatus.FS` with Off trapping F opcodes and Dirty tracking. RV64 adds FCVT.L[U].S / FCVT.S.L[U].
- **Optional follow-on:** D extension (FLEN = 64, NaN-boxing of single values).
- **Exit:** `rv32uf-p-*` / `rv64uf-p-*` pass; Linux can then be rebuilt with `CONFIG_FPU=y` and an `rv32imafc` userland.

#### B9.2 C extension (compressed instructions) — planned, not needed by Linux
- **Why:** Linux and OpenSBI boot without C, but C is preferable: about 25–30 % smaller code (less I-cache pressure, faster sim boot), and stock `rv32imac`/`rv64imac` userlands and distro binaries assume it.
- **shared_pkg:** none (C has no new architectural state); `misa.C` = bit 2.
- **Design:**
  - **Fetch aligner** in `fetch_stage`: a 32-bit instruction may start at any 16-bit boundary, so it can straddle two I-cache words and two cache lines. A small buffer holds the upper half-word of the previous fetch; a straddling instruction takes two I-cache accesses (and, after the MMU, two translations).
  - **Expander** `c_expander.sv` (combinational, in `fetch_stage` before IF/ID): maps each 16-bit RVC encoding to its 32-bit equivalent, so decode and everything after it are unchanged. XLEN-dependent encodings via `IS_RV64` (C.LD/C.SD/C.ADDIW on RV64, C.JAL/C.FLW on RV32). Reserved/illegal RVC encodings (including all-zero) raise illegal instruction with `mtval` = the 16-bit encoding.
  - **PC rules:** `PC + 2` for compressed, `PC + 4` otherwise; the link value of C.JAL/C.JALR is `PC + 2`. Carry an `IsCompressedX` bit down the pipeline for that.
  - **IALIGN = 16:** branch/jump targets only need `target[0] = 0`, so instruction-address-misaligned can no longer happen on RV32IC; `mepc[0]` = 0 and `mepc[1]` becomes writable.
  - **Faults:** a fetch fault on the second half of a straddling instruction reports `mtval` = the address of that second half (Privileged spec).
- **Verification:** the ISS learns RVC; the generator emits mixed 16/32-bit streams, including straddling ones; `rv32uc-p-*` / `rv64uc-p-*`; a fetch-aligner SVA env (`Verification/Fetch/`).
- **Software:** `CONFIG_RISCV_ISA_C=y`, Buildroot ISA `rv32imac`, OpenSBI `PLATFORM_RISCV_ISA=rv32imac_zicsr_zifencei`, DT `riscv,isa-extensions` gains `"c"`.
- **Exit:** compressed test suites pass at both XLENs; Linux boots to the shell with a `rv32imac` userland.

#### Optional blocks

| Block | Value |
|---|---|
| B9.3 Svadu (hardware A/D update in PTW) | Fewer page faults |
| B9.4 Zicbom + non-coherent DMA devices | Real peripherals |
| B9.5 Sv39 + RV64 Linux (the RV64 datapath exists since B1.1) | Route to Debian/Fedora |
| B9.6 SMP (ACLINT, HSM, LR/SC across harts) | Multi-core |

---

## 5. Dependency graph

```
B1.0 ─▶ B1.1 ─▶ B1.2 ─▶ B1.3 ─▶ B1.4 ─▶ B1.5 ─▶ B1.6 ─▶ B1.7 ─▶ B1.8      (Phase 1, first)
                                                                   │
B0.1 ─▶ B0.2 ─▶ B0.3 ─▶ B0.4  (in parallel; adds riscv-tests/Spike) │
                          │                                         │
                          └───────────────────┬─────────────────────┘
                                              ▼
                         ┌────────────────────┼─────────────────────────────┐
                         ▼                    ▼                             ▼
                 B2.0 ─▶ B2.1 (A)     B3.1 ─▶ B3.2 ─▶ B3.3 ─▶ B3.4      B7.1 ─▶ B7.2
                         │                             │                    │
                         │                             ▼                    ├─▶ B7.3 ─▶ B7.4
                         │                           B4.1 ─▶ B4.2           ├─▶ B7.5
                         │                             │                    ├─▶ B7.6
                         │                             ▼                    └─▶ B7.7
                         │             B5.0 ─▶ B5.1 ─▶ B5.2 ─▶ B5.3 ─▶ B6.1      │
                         │                                       │              │
                         └───────────────────────────────────────┴──▶ B8.1 ◀────┘
                                                                        │
                                               B8.2 ─▶ B8.3 ─▶ B8.4 ─▶ B8.5 ─▶ shell
                                                                                 │
                                                                     B9.1 (F), B9.2 (C)
```

B1.0 comes first because every later Phase 1 block is judged by its checker.
B1.1–B1.8 touch overlapping files, so they land as one reviewed series in the
order shown; each step leaves both XLENs green.

Parallel tracks once Phase 1 is done:
- **Core track:** A → M-mode → S-mode → MMU → PMP
- **SoC track:** B7.x, which only touches new files plus `riscv_processor` ports
- **Software track:** DTS, OpenSBI and Buildroot builds can start on Day 1 against QEMU `virt` (`qemu-system-riscv32 -M virt -bios fw_payload.bin`), so the software image is already proven when the RTL is ready

---

## 6. Regression gates

A phase is closed only when its gate is green **and** every earlier gate is still green, **at XLEN = 32 and at XLEN = 64**.

| Phase | Gate |
|---|---|
| 1 | 9 legacy tops + ISS-checked `risc_top` green at both XLENs, 10 random seeds each, random AXI latency on; mutation proof of B1.0 recorded |
| 0 | Tooling builds; then `rv32ui-p-*`/`rv32um-p-*` (and `rv64ui`/`rv64um`) 100 % and Spike cosim 0 mismatches over 10 seeds on the Phase 1 core |
| 2 | + `rv32ua-p-*` 100 % |
| 3 | + `rv32mi-p-*` 100 % (non-S tests) |
| 4 | + `rv32si-p-*` 100 %; random-interrupt cosim 10k events clean |
| 5 | + `rv32ui-v-*`, `rv32um-v-*`, `rv32ua-v-*` 100 % |
| 6 | + riscv-arch-test `privilege` + `pmp` via RISCOF |
| 7 | + bare-metal UART hello on `riscv_soc_top`; AXI assertions clean on all ports |
| 8 | B8.1 suite → OpenSBI banner → kernel `earlycon` → BusyBox prompt |

Every gate is run by one script: `Questa/do/regress_all.sh`. It runs the legacy tops, the compliance list and the cosim seeds, and prints a single PASS/FAIL table. Add it in B0.4 and grow it with every block.

---

## Appendix A — why `DATA_WIDTH = 64` was broken

Concrete reasons the 32 → 64 flip failed on 2026-10-21. All of them are fixed
in B1.1 (A4 also needs B1.3; A6 is B1.6; A7 is B1.7). Only A9 stays open: the
single-cycle 64 × 64 multiplier and divider are functionally correct but too
big for timing, which is a later micro-architecture task, not a defect.

| # | Location | Problem at XLEN = 64 |
|---|---|---|
| A1 | `fetch_stage`, `decode_stage`, `riscv_processor` | `InstructionD/F` declared `[DATA_WIDTH-1:0]`; the I-cache returns a 64-bit word holding **two** instructions, with no selection by `PC[2]` |
| A2 | `fetch_stage.sv:149,154` | NOP literal `32'h00000033` assigned to a 64-bit register (works by zero-extension, but signals the coupling) |
| A3 | `decode_stage.sv:319–325` | Immediates sign-extended with fixed `{20{…}}` / `{12{…}}` → 52/44-bit results, upper bits zero → wrong sign |
| A4 | `alu_decoder` / `opcode_decoder` | No RV64 ops: `OP-IMM-32`, `OP-32` (`ADDIW`, `ADDW`, `SUBW`, `SLLW`, `SRLW`, `SRAW`, `MULW`, `DIVW`, …), `LD`, `SD`, `LWU`; 6-bit shamt for `SLLI/SRLI/SRAI` |
| A5 | `csr_file.sv:85,97,108–120,283–295`, `csr_defs.sv:14–47` | 32-bit literals: `misa` must be `0x8000…` (MXL = 2), `mcause` interrupt bit must be bit 63, masks are 32-bit, `{27'b0, Rs}` gives width mismatches |
| A6 | `csr_file.sv:51` | 4096 × 64-bit flop array: huge, and still not synthesizable as RAM |
| A7 | `execute_stage.sv:142` | FPU hard-wired `PRECISION(SINGLE)` while the FPR file is `DATA_WIDTH` wide; no NaN-boxing |
| A8 | `execute_stage.sv:176–221` | Mux padding inputs `32'b0` |
| A9 | `risc_alu` + `wallace_tree` + `non_restoring_divider` | Single-cycle 64 × 64 multiply and 64-bit combinational divide: functionally OK in sim, but enormous and unusable for timing |
| A10 | `risc_data_memory.sv:103,124,143`, `risc_instruction_memory.sv:64,69` | Word index hard-coded as `addr[ADDR_WIDTH-1:2]`, wrong for 8-byte words; `raddr + ((1 << rsize) >> 2)` assumes 4-byte beats |
| A11 | `cache.sv:783,788` | Word select `CpuOffset[OFF_W-1:2]` assumes 4-byte words |
| A12 | `riscv_processor` vs `shared_pkg` | `ADDR_WIDTH` is used both as PC/VA width and as the RAM index width (`FINAL_ADDR_WIDTH = 10`). RV64 needs `XLEN = 64` VA, about 56-bit PA, and a separate small RAM index |
| A13 | `Verification/*` | Interfaces and items use `FINAL_DATA_WIDTH`, but predictors and the Python generator assume 32-bit semantics (sign extension, `cycle` aliasing, 4-byte strides) |

---

## Appendix B — Linux-visible contract checklist

Tick each one before running OpenSBI (B8.3). Each line is a known silent-hang cause.

- [ ] `misa` and the DT `riscv,isa-extensions` match the RTL exactly
- [ ] Reset: `a0 = mhartid`, `a1 = DTB` address at the OpenSBI entry (boot ROM)
- [ ] `satp = 0` at reset; translation is off in M unless MPRV is set
- [ ] `mtime` is monotonic, and DT `timebase-frequency == clk / TIMEBASE_DIV`
- [ ] `rdtime` works in S/U, or traps illegal (OpenSBI emulates it) when `mcounteren.TM = 0`
- [ ] `mtval` holds the instruction bits on illegal instruction (OpenSBI's emulation path reads it)
- [ ] Misaligned load/store traps with `mtval = address` (OpenSBI emulates them using MPRV)
- [ ] `mip.STIP` is writable from M (OpenSBI timer injection without Sstc)
- [ ] `mstatus.SUM` honored (the kernel's `copy_from_user` faults without it)
- [ ] An `sc` after any trap or xRET fails (reservation cleared)
- [ ] `sfence.vma` flushes both TLBs and the pipeline; a `satp` write is serializing
- [ ] `fence.i` makes D-cache stores visible to fetch
- [ ] PMP: at least 8 entries, NAPOT and TOR correct, locked entries apply to M
- [ ] Kernel loaded 4 MiB-aligned (RV32); OpenSBI region marked reserved in the DT (OpenSBI does this automatically)
- [ ] Uncached CLINT/PLIC/UART: no cache allocation, single-beat accesses with the correct `MWStrb`

---

## Appendix C — references

- RISC-V Unprivileged ISA spec: RV32I, M, A, Zicsr, Zifencei, Zicntr chapters
- RISC-V Privileged spec: machine, supervisor, Sv32, PMP, Svade
- RISC-V SBI spec: TIME, IPI, RFENCE, HSM extensions
- RISC-V ACLINT and PLIC specs
- Linux `Documentation/arch/riscv/boot.rst`; DT bindings `riscv/cpus.yaml`, `riscv/extensions.yaml`
- OpenSBI `docs/platform/generic.md`, `docs/firmware/fw_payload.md`
- `riscv-tests` (`isa/rv32{ui,um,ua,mi,si}`, `-p`/`-v` environments), `riscv-arch-test` + RISCOF
- Ibex co-simulation docs (RVFI + Spike DPI pattern)
- Reference designs at a similar scope: KianV (RV32IMA + Sv32 + Sstc, Verilog), VexRiscv-SMP + LiteX, quasiSoC, cnlohr `mini-rv32ima` (C reference)
