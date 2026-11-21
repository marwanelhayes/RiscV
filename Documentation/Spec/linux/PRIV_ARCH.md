# Privileged architecture: M/S/U modes, traps, delegation, xRET, WFI, SFENCE.VMA

Spec: Priv "Machine-Level ISA" and "Supervisor-Level ISA"
([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc),
[supervisor.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/supervisor.adoc)).
Ratified edition 20240411 (Priv v1.13) per
[riscv.org](https://riscv.org/specifications/ratified/); the RVA20S64 profile pins
Priv 1.11 as its floor ([rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc)).
Hardware: [modules/TRAP_COMMIT_UNIT.md](modules/TRAP_COMMIT_UNIT.md). Plan blocks
B3.1–B3.4, B4.1–B4.2. Back to [index](README.md).

## 1. Required by Linux

- OpenSBI runs in M, Linux in S, user programs in U. OpenSBI requires "At least one
  HART should have S-mode support" and direct-mode `mtvec`
  ([platform_requirements.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md)).
- OpenSBI delegates S/U traps only if `misa.S = 1` (`delegate_traps()` returns early
  otherwise). It delegates `SSIP|STIP|SEIP` in `mideleg` and
  misaligned-fetch, breakpoint, U-ecall and (default platform feature) the three
  page faults in `medeleg`
  ([sbi_trap.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_trap.c)).
  Illegal-instruction and misaligned load/store stay in M and are **emulated** by
  OpenSBI — which needs MPRV (§5).

## 2. State to add

### 2.1 Privilege mode

`PrivMode[1:0]`: U = `00`, S = `01`, M = `11`. Reset → M. Not software-visible as a
CSR; visible via `mstatus.MPP/SPP` after traps.

`misa`: set **S** (bit 18) and **U** (bit 20) (plus A, bit 0). RV32 value for
`IMASU` (+F today): `0x4014_1121` — PLAN_B B3.1 lists the same. The DT ISA string
must match.

### 2.2 `mstatus` fields (RV32 layout; RV64 identical in bits 0–22, see note)

| Bit(s) | Field | Today (`Design/csr_file.sv:118-126`) | Required behaviour |
|---|---|---|---|
| 1 | SIE | absent | S global interrupt enable |
| 3 | MIE | present | — |
| 5 | SPIE | absent | — |
| 6 | UBE | absent | read-only 0 (little-endian) |
| 7 | MPIE | present | — |
| 8 | SPP | absent | 1 bit: previous mode for S traps (0 = U, 1 = S) |
| 10:9 | VS | absent | read-only 0 (no V) |
| 12:11 | MPP | **hard-wired `11`** (`:123`) | WARL, holds U/S/M; MRET sets it to U |
| 14:13 | FS | hard-wired Dirty (`:124`) | see [ISA_F_D](ISA_F_D.md) §3 |
| 16:15 | XS | absent | read-only 0 |
| 17 | MPRV | absent | "read-only 0 if U-mode is not supported; otherwise, it must be writable" |
| 18 | SUM | absent | S may load/store U pages |
| 19 | MXR | absent | loads from X-only pages allowed |
| 20 | TVM | absent | traps `satp` access and SFENCE.VMA in S |
| 21 | TW | absent | traps WFI in S (after bounded time) |
| 22 | TSR | absent | traps SRET in S |
| XLEN−1 | SD | constant 1 (`:125`) | `FS==11 \|\| XS==11 \|\| VS==11` |

RV32 `mstatush` (`0x310`): MBE/SBE read-only 0 (exists today, reads 0,
`Design/csr_file.sv:166`). RV64: `UXL[33:32]` and `SXL[35:34]` read-only `10`
(64-bit) once S/U exist — today they read 0, which is correct only while S/U are absent.

`sstatus` (`0x100`) is a **view** of `mstatus` (same flops), exposing SIE, SPIE,
UBE, SPP, VS, FS, XS, SUM, MXR, SD (and UXL on RV64). Never a separate register.

### 2.3 Interrupt bits (`mip`/`mie`, `sip`/`sie` views)

| Bit | Name | Source | Writable in `mip`? |
|---|---|---|---|
| 1 | SSIP | software (M or S writes; SBI IPI) | yes (M), via `sip` from S if delegated |
| 3 | MSIP | CLINT `msip` | no (read-only) |
| 5 | STIP | OpenSBI injection, or Sstc compare | yes from M without Sstc; read-only with Sstc and `STCE=1` |
| 7 | MTIP | CLINT `mtime ≥ mtimecmp` | no |
| 9 | SEIP | PLIC context 1 (S), OR-ed with a software-writable bit | yes (M writes the software bit) |
| 11 | MEIP | PLIC context 0 (M) | no |

`sip`/`sie` show only the bits delegated in `mideleg`. Priority for simultaneous
interrupts: **MEI, MSI, MTI, SEI, SSI, STI** (machine.adoc).

### 2.4 S-mode CSRs

| CSR | Addr | Notes |
|---|---|---|
| `sstatus` | `0x100` | view of `mstatus` |
| `sie` | `0x104` | view of `mie & mideleg` |
| `stvec` | `0x105` | BASE + MODE (direct/vectored); Sstvecd: direct must hold any 4-byte-aligned address |
| `scounteren` | `0x106` | see [ISA_ZICNTR_TIME](ISA_ZICNTR_TIME.md) |
| `senvcfg` | `0x10A` | required with U-mode; fields read-only 0 are fine without Zicbo*/pointer masking |
| `sscratch` | `0x140` | plain register |
| `sepc` | `0x141` | `[1:0]=0` (no C) |
| `scause` | `0x142` | interrupt bit + code |
| `stval` | `0x143` | Sstvala (RVA20S64): faulting VA for page/access/misaligned faults, instruction bits for illegal |
| `sip` | `0x144` | view |
| `satp` | `0x180` | see [MMU_SV32_SV39](MMU_SV32_SV39.md) |
| `stimecmp(h)` | `0x14D`/`0x15D` | Sstc, optional |
| `medeleg` | `0x302` | writable per cause; `medeleg[11]` (ecall from M) is read-only 0 |
| `mideleg` | `0x303` | writable SSIP/STIP/SEIP bits (M-level bits read-only 0) |
| `mcounteren` | `0x306` | |
| `menvcfg(h)` | `0x30A`/`0x31A` | mandatory with U-mode |

### 2.5 Exception causes (`mcause`/`scause`, interrupt bit clear)

| Code | Cause | Can this core raise it today? |
|---|---|---|
| 0 | Instruction address misaligned | yes (`Design/execute_stage.sv:426-430`) |
| 1 | Instruction access fault | **no** (needs PMP / bus error) |
| 2 | Illegal instruction | yes |
| 3 | Breakpoint | yes |
| 4 / 6 | Load / Store-AMO address misaligned | yes (`:439-458`) |
| 5 / 7 | Load / Store-AMO access fault | **no** |
| 8 / 9 / 11 | ECALL from U / S / M | **only 11** (`:435-438`) |
| 12 / 13 / 15 | Instruction / Load / Store-AMO page fault | **no** |

Synchronous priority (machine.adoc "Synchronous exception priority"): instruction
breakpoint → instruction page/access fault (fetch translation) → instruction access
fault (physical) → illegal / instruction-misaligned / ECALL / EBREAK / data
breakpoint → (optionally) data misaligned → data page/access fault (translation) →
data access fault (physical) → data misaligned (if not raised earlier).

## 3. Trap entry, routing and return

**Routing.** An exception with cause `c` taken in mode `x` goes to S iff
`x ≤ S` and `medeleg[c] = 1`; otherwise to M. Traps never go to a *less*
privileged mode than the one they occur in. Interrupt `i` targets S iff
`mideleg[i] = 1`.

**Interrupt enable.** An interrupt targeting mode `y` is taken when it is pending and
enabled in `mie` and either the current mode `x < y`, or `x == y` and `mstatus.yIE = 1`.
Interrupts targeting a lower mode than the current one are never taken (an
S-interrupt is masked while in M).

**Entry to M:** `mepc ← PC`, `mcause`, `mtval`, `MPIE ← MIE`, `MIE ← 0`,
`MPP ← mode`, `mode ← M`, `PC ← mtvec` (+4·cause for vectored interrupts).
**Entry to S:** `sepc`, `scause`, `stval`, `SPIE ← SIE`, `SIE ← 0`,
`SPP ← mode` (0 = U, 1 = S), `mode ← S`, `PC ← stvec`.

**MRET** (`0x30200073`, legal only in M): `mode ← MPP`, `MIE ← MPIE`, `MPIE ← 1`,
`MPP ← U`; if the new mode is less privileged than M, `MPRV ← 0`.
**SRET** (`0x10200073`): illegal in U; illegal in S when `TSR = 1`. `mode ← SPP`,
`SIE ← SPIE`, `SPIE ← 1`, `SPP ← U`, `MPRV ← 0`.

**WFI** (`0x10500073`): a NOP is a legal implementation in M and S. With S-mode
present, WFI in U "causes an illegal-instruction exception, regardless of the value
of the TW bit, unless the instruction completes within an implementation-specific,
bounded time limit" — a NOP completes immediately, so NOP stays legal. `TW = 1` in S:
same rule. Stalling until `(mip & mie) ≠ 0` (B3.4) only saves simulation time.

**SFENCE.VMA** (`0001001 rs2 rs1 000 00000 1110011`): illegal in U, illegal in S when
`TVM = 1`. Orders prior page-table stores before later implicit translation reads;
implementation = flush TLBs (all, or by ASID/VA) + flush younger instructions.
See [MMU_SV32_SV39](MMU_SV32_SV39.md).

## 4. What exists today (M-mode only)

| Item | Evidence |
|---|---|
| Trap decision in EX, same cycle, on `Commit = ValidE && !StallE` | `Design/execute_stage.sv:412`; `Design/csr_file.sv:221-252` |
| Interrupts MEI > MSI > MTI gated by `MIE`; vectored `mtvec` | `Design/csr_file.sv:228-251` |
| MRET: `MIE ← MPIE`, `MPIE ← 1` | `Design/csr_file.sv:293-297` |
| SYSTEM decode: MRET, ECALL, EBREAK, WFI (NOP); everything else illegal | `Design/decode_stage.sv:398-419` |
| `medeleg`/`mideleg` read 0, writes ignored | `Design/csr_file.sv:149-150,322-325` |
| No privilege register; `MPP` constant `11` | `Design/csr_file.sv:123` |

## 5. MPRV/SUM/MXR — easy to forget, fatal for OpenSBI

OpenSBI reads the trapping instruction and emulates misaligned loads/stores using
loads executed in M with `mstatus.MPRV = 1` (and `MXR = 1` for instruction reads),
so the access is translated and permission-checked **as if from MPP's mode**
(`sbi_unpriv.c` `MSTATUS_MPRV | MSTATUS_MXR`,
[OpenSBI](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_unpriv.c)).
Requirements:

- MPRV affects **data** accesses only (not fetch).
- Effective data privilege = `MPRV ? MPP : PrivMode`; translation is active when the
  effective mode is S/U and `satp.MODE ≠ Bare`.
- SUM: S-mode data access to `U=1` pages allowed only when `SUM = 1` (the kernel's
  `copy_from_user` toggles SUM). Fetch from `U=1` pages in S is always a fault.
- MXR: loads from pages with `X=1, R=0` succeed when `MXR = 1`.

## 6. What must change

| # | Change | Where | Plan |
|---|---|---|---|
| 1 | `PrivMode` register; `priv_mode_t` enum | `Design/shared_pkg.sv`, `Design/csr_file.sv` | B3.2 |
| 2 | `mstatus` fields of §2.2, `sstatus` view, writable MPP (WARL: legalise reserved `10` to a supported value) | `Design/csr_file.sv`, `Design/csr_defs.sv` | B3.2, B4.1 |
| 3 | S CSRs of §2.4; CSR privilege check `csr[9:8] ≤ mode` | `Design/csr_file.sv`, `Design/shared_pkg.sv:126-155` | B4.1 |
| 4 | Writable `medeleg`/`mideleg`, routing logic, S trap entry | `Design/csr_file.sv` | B4.1 |
| 5 | Interrupt arbitration across modes (§3), six sources | `Design/csr_file.sv:228-237` | B4.2 |
| 6 | Decode SRET, SFENCE.VMA (rs1/rs2 allowed non-zero), with mode/TSR/TVM legality | `Design/decode_stage.sv:398-419` | B4.1, B5.3 |
| 7 | ECALL cause = 8/9/11 from `PrivMode` | `Design/execute_stage.sv:435-438` | B3.2 |
| 8 | MPRV/SUM/MXR plumbed to the D-side MMU/PMP | `memory_stage` | B5.3 |
| 9 | Interrupt lines: `MTimerIrq`, `MSoftIrq`, `MExtIrq`, `SExtIrq` (PLIC ctx 1) | `Design/riscv_processor.sv:42-44` | B7.x |
| 10 | Commit point at M (privilege changes and CSR writes after older faults resolve) | all stages | B5.0 |

## 7. Verification hooks

- `rv32mi-p-*`, `rv32si-p-*` (and rv64) — physical-memory privileged tests in
  [riscv-tests](https://github.com/riscv-software-src/riscv-tests).
- ACT privileged suites ([riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test)).
- ISS: add `PrivMode`, S CSRs, delegation, and the interrupt-enable matrix.
  Interrupts must be injected into the ISS at the exact commit where the DUT takes
  them — `commit_checker` already does this for M interrupts
  (`Verification/Risc/commit_checker.sv:205`).
- Cross coverage needed (absent today): `mode × cause × delegated × xIE` and
  `interrupt source × mode × mideleg × mie`.
