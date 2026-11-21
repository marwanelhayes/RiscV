# Precise-exception / commit-at-M changes and privilege logic

Not a new file so much as a re-wiring of `execute_stage`, `csr_file`,
`hazard_unit` and every pipeline register. Spec basis:
[PRIV_ARCH](../PRIV_ARCH.md). Plan blocks B5.0 (commit at M), B3.2, B4.1, B4.2.
Back to [index](../README.md).

## 1. Purpose

Make every trap precise once faults can be discovered **after** EX:

| Fault | Discovered in |
|---|---|
| Illegal, ECALL/EBREAK, misaligned (today) | D/E |
| Instruction page fault / access fault | F (I-TLB/PMP/bus) |
| Load/store page fault, access fault, bus error | M (D-TLB/PMP/bus) |

Today the commit point is EX: the CSR file takes the trap when
`Commit = ValidE && !StallE` (`Design/execute_stage.sv:412`;
`Design/csr_file.sv:239-243`). If the older instruction in M later faults, the
EX instruction has already committed its CSR write, branch redirect or trap.
That is the definition of an imprecise exception.

## 2. Contract (the commit point is M)

1. Every pipeline register carries `ValidX`, `PCX` (real PC, not `PCPlus4X`),
   `ExcValidX`, `ExcCauseX[4:0]` (binary `mcause` code — use PLAN_B's
   `exc_cause_t`), `ExcTvalX[XLEN-1:0]`.
2. The **first** stage that detects a fault sets `ExcValid/Cause/Tval`; later
   stages never overwrite an earlier exception (that gives the spec priority:
   fetch faults before decode faults before data faults for the same instruction).
3. An instruction with `ExcValidX = 1` has no side effects in any stage: no
   D-cache request, no CSR write, no redirect, no register write.
4. At M, `TrapTakenM = ValidM && !StallM && (ExcValidM || InterruptPendingM)`.
   On `TrapTakenM`: write the trap CSRs, set the privilege mode, redirect to the
   vector, flush F/D/E/M, suppress the M instruction's write-back.
5. Interrupts are sampled at M on a valid, advancing instruction (that instruction
   becomes `mepc`/`sepc` and does not execute).
6. **Serializing instructions** — CSR writes, MRET, SRET, ECALL, EBREAK, WFI,
   SFENCE.VMA, FENCE.I — perform their side effects at M, then flush F/D/E and
   refetch at `PC + 4` (or the vector). Simplest correct rule: flush after *every*
   SYSTEM-opcode instruction.
7. Loads/stores that *could* fault must not perform a store (or a side-effecting
   MMIO read) before the fault is known: translate/PMP-check in M **before** the
   D-cache write is issued (same cycle combinationally, or one extra cycle).
8. `hazard_unit` stays the only stall/flush source (PLAN_B §3.4 rule 1); new
   requests: `TrapTakenM`, `SerializeM`, `ITLBMissF`, `DTLBMissM`, `PTWBusy`,
   `AmoBusyM`, `FlushBusyM`.

## 3. Privilege/delegation logic inside `csr_file`

Inputs: `PrivMode`, `ExcValidM`, `ExcCauseM`, `ExcTvalM`, `PCM`, `mip`, `mie`,
`mideleg`, `medeleg`, `mstatus.{MIE,SIE}`, `MRetM`, `SRetM`.

```
// pseudo-RTL, one always_comb
IrqM  = pending & enabled & ~mideleg & ((PrivMode != M) | MIE)   // to M
IrqS  = pending & enabled &  mideleg & ((PrivMode == U) | (PrivMode == S & SIE))
// priority MEI MSI MTI SEI SSI STI over (IrqM | IrqS), M-targeted first
ToS   = (PrivMode != M) & (Interrupt ? mideleg[code] : medeleg[code])
```

Outputs: `TrapTakenM`, `TrapToS`, `CsrOutPC` (`mtvec`/`stvec`/`mepc`/`sepc`),
`PrivModeNext`, plus the CSR read data. `mcause`/`scause` interrupt bit is
`XLEN-1` (already correct for both widths: `Design/csr_file.sv:287`).

## 4. Ports added (Unison naming)

| Module | Port | Stage | Meaning |
|---|---|---|---|
| every stage | `ExcValidX`, `ExcCauseX`, `ExcTvalX`, `PCX` | F→W | exception carried with the instruction |
| `csr_file` | `PrivMode` (out), `MPRVEff`, `SUM`, `MXR`, `Satp` (out) | — | to MMU/PMP |
| `csr_file` | `MTimerIrq`, `MSoftIrq`, `MExtIrq`, `SExtIrq`, `MTime[63:0]` (in) | — | from CLINT/PLIC |
| `hazard_unit` | `TrapTakenM`, `SerializeM` (in) | M | flush F/D/E/M |

## 5. Migration steps that keep the design green

1. Add `PCX` and the `Exc*X` fields, still raising everything in EX → no behaviour
   change; the ISS commit checker must stay at zero mismatches.
2. Move the trap decision and CSR side effects from EX to M. The ISS checker is
   architectural, so "no change in mismatches" is the proof (PLAN_B B5.0 already
   states this).
3. Only then add new fault sources (TLB, PMP, bus).

`commit_checker` currently samples the commit at EX
(`Verification/Risc/commit_checker.sv:199-241`); it must move to the M commit at
step 2. Better: drive it from an RVFI-style retirement port (PLAN_B B0.2), so the
checker never depends on which stage commits.

## 6. Verification hooks

- SVA (bind from the TB): `ExcValidM |-> !DCacheWriteEn`; `TrapTakenM |=> !ValidE &&
  !ValidM` (flush took effect); "at most one retirement per cycle"; "no retirement
  between `TrapTakenM` and the first vector fetch".
- ISS lock-step at the M commit with random faults injected from the memory model
  (bus error responses) — this is exactly how Ibex's cosim stays in sync for memory
  errors ([cosim.rst](https://github.com/lowRISC/ibex/blob/master/doc/03_reference/cosim.rst)).
- `rv32mi-p-*`, `rv32si-p-*` (riscv-tests).
