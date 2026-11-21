# F and D extensions (floating point) — what Linux needs and what the FPU covers

Spec: Unpriv "F" and "D" chapters
([f-st-ext.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/f-st-ext.adoc),
[d-st-ext.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/d-st-ext.adoc));
Priv `mstatus.FS` ([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc)).
Plan blocks B1.7 (done), B9.1. Back to [index](README.md).

## 1. Is it required? No — and F alone does not help

| Fact | Source |
|---|---|
| `CONFIG_FPU` is an ordinary option ("When this option is disabled, neither the kernel nor userspace may use the floating point unit") | [arch/riscv/Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig) |
| With `CONFIG_FPU=y` the kernel is built with `…fd` (F **and** D together) | [arch/riscv/Makefile](https://github.com/torvalds/linux/blob/master/arch/riscv/Makefile) line 63 |
| A hart that reports F but not D gets F removed: "This kernel does not support systems with F but not D" | [arch/riscv/kernel/cpufeature.c](https://github.com/torvalds/linux/blob/master/arch/riscv/kernel/cpufeature.c) |
| OpenSBI treats F and D as optional extensions detected at runtime | [platform_requirements.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md) |

Consequence: the current single-precision FPU is **invisible to Linux** under any
configuration. For the first boot: `CONFIG_FPU=n`, soft-float userland (`ilp32` /
`lp64` ABI), and the device tree must **not** list `"f"` or `"d"`. PLAN_B already
says this; the new information is that adding F completeness (B9.1) gives Linux
nothing unless D is added too.

## 2. Instruction inventory (F; D is the same set with `fmt = 01` / `.D`)

| Group | Opcode | Instructions | In RTL? |
|---|---|---|---|
| Loads/stores | LOAD-FP `0000111`, STORE-FP `0100111` (funct3 `010` W, `011` D) | FLW, FSW (FLD, FSD) | **no** (opcodes not in `opcode_t`, `Design/shared_pkg.sv:21-37`) |
| Fused multiply-add (R4) | `1000011` `1000111` `1001011` `1001111` | FMADD, FMSUB, FNMSUB, FNMADD | **no** |
| Arithmetic | OP-FP `1010011` | FADD FSUB FMUL FDIV FSQRT | yes (`Design/fpu_decoder.sv:13-19`) |
| Sign inject, min/max | OP-FP | FSGNJ[N/X], FMIN, FMAX | yes |
| Compare/classify (write **integer** rd) | OP-FP | FEQ FLT FLE FCLASS | yes (D20 fixed: `MoveOperationD = FPUToReg`, `Design/fpu_decoder.sv:148-193`) |
| Int↔FP convert | OP-FP | FCVT.W[U].S, FCVT.S.W[U] | yes |
| RV64 converts | OP-FP (rs2 = `00010`/`00011`) | FCVT.L[U].S, FCVT.S.L[U] | **no** (`case(Rs2)` only `00000/00001`, `Design/fpu_decoder.sv:145-212`) |
| Moves | OP-FP | FMV.X.W (sign-extends on RV64), FMV.W.X | yes (`Design/execute_stage.sv:391-392`) |
| D only | OP-FP | FCVT.S.D, FCVT.D.S, FMV.X.D/FMV.D.X (RV64) | **no** |

Architectural state:

| State | Requirement | RTL |
|---|---|---|
| `f0`–`f31`, FLEN = 32 (F) / 64 (D) | D needs FLEN = 64 and **NaN-boxing** of single values (upper 32 bits all 1s; a non-boxed value read as single is the canonical NaN) | FLEN = 32 (`Design/shared_pkg.sv:366-367`); FPU instance hard-wired `PRECISION(SINGLE)` (`Design/execute_stage.sv:174`). The units implement DOUBLE except sqrt (`Design/shared_pkg.sv:196`) |
| `fcsr` = `frm[7:5]` + `fflags[4:0]` (NV DZ OF UF NX) | flags **accrue** (sticky OR) on every FP op | `fflags` only changes on CSR writes (`Design/csr_file.sv:301-303`); the FPU's status outputs are not IEEE flags (README "FPU status outputs are not IEEE `fflags`") |
| Dynamic rounding with invalid `frm` (101, 110, 111) → illegal | required | static reserved `rm` → illegal is done (`Design/fpu_decoder.sv` `RoundModeReserved`); dynamic-with-invalid-`frm` check: not found in RTL |
| `mstatus.FS` | "If the F extension is implemented, the FS field shall not be read-only zero"; when FS = Off, FP instructions and FP CSR accesses are illegal; FP state writes set Dirty | hard-wired Dirty (`Design/csr_file.sv:124-125`) |

## 3. The `mstatus.FS` problem once S/U modes exist

Hard-wired `FS = Dirty` is legal-looking for an M-only core, but with Linux:

- The kernel clears FS at boot and, with `CONFIG_FPU=n`, never saves FP state. A
  user program that executes an F instruction (a mis-built binary, or a test) will
  **execute** instead of trapping, and FP registers leak between processes. Spec
  intent is that `FS = Off` makes those instructions illegal.
- With `CONFIG_FPU=y` (after D exists), the kernel relies on FS for lazy
  save/restore; hard-wired Dirty forces a save on every context switch (correct
  but slow) and is not what the spec describes.

Minimum fix (small, recommended even with `CONFIG_FPU=n`): make FS a real 2-bit
field, trap FP opcodes and `fflags/frm/fcsr` accesses as illegal when FS = Off, and
set FS = Dirty whenever an FP register or `fcsr` is written. `SD` follows FS.

## 4. What must change

For the first Linux boot: **only §3** (FS writable/Off-traps), plus keep `"f"` out of
the DT. Everything else is B9.1 and only pays off with D:

| # | Change | Size |
|---|---|---|
| 1 | FS writable, Off → illegal, Dirty tracking | small (`csr_file`, decode) |
| 2 | IEEE `fflags` from each unit, OR-accumulated into `fflags` at commit | medium (every `flp_*` unit) |
| 3 | FLW/FSW through the D-cache port (store data from FPR) | medium (decode, memory stage) |
| 4 | FMADD family (single rounding — not FMUL then FADD) | large (new fused datapath) |
| 5 | FCVT.L[U].S / FCVT.S.L[U] for RV64 | small–medium |
| 6 | D: FLEN = 64, NaN-boxing, D sqrt, FCVT.S.D/D.S, FMV.X.D | large |
| 7 | Dynamic `frm` invalid → illegal | small |
| 8 | DT `riscv,isa-extensions` += `"f","d"`; `CONFIG_FPU=y`; `ilp32d`/`lp64d` userland | software |

## 5. Verification hooks

- The FPU env is the strongest part of the current testbench: exact SV reference
  (`Verification/FPU/flp_ref_pkg.sv`) and an independent Python golden via DPI
  (`Verification/FPU/dpi/fpu_ref.c`, `fpu_golden.py`). Keep it.
- Add Berkeley SoftFloat/TestFloat vectors as a third reference — the de-facto
  industry reference for IEEE-754 rounding/flags (TestFloat:
  <http://www.jhauser.us/arithmetic/TestFloat.html>, not fetched in this audit).
- `rv32uf-p-*` / `rv64uf-p-*`, `rv*ud-p-*` from
  [riscv-tests](https://github.com/riscv-software-src/riscv-tests).
- ISS: today it "models as gaps" the missing `fflags` accrual
  (`Verification/Risc/riscv_iss_pkg.sv:21-22`); once flags exist, remove the gap so
  the ISS checks them.
