# Zicsr (CSR instructions and access rules)

Spec: Unpriv "Zicsr"
([zicsr.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zicsr.adoc));
Priv "CSR address mapping conventions" and "CSR listing"
([csrs.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/csrs.adoc)).
The individual CSRs are specified in [PRIV_ARCH](PRIV_ARCH.md),
[ISA_ZICNTR_TIME](ISA_ZICNTR_TIME.md), [MMU_SV32_SV39](MMU_SV32_SV39.md), [PMP](PMP.md).
Back to [index](README.md).

## 1. Required by Linux

Yes. Kernel and OpenSBI march strings include `zicsr`
([Makefile](https://github.com/torvalds/linux/blob/master/arch/riscv/Makefile),
[OpenSBI requirements](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md)).

## 2. Instructions (opcode SYSTEM `1110011`, `csr = inst[31:20]`)

| funct3 | Instruction | Reads CSR? | Writes CSR? |
|---|---|---|---|
| `001` | CSRRW rd, csr, rs1 | only if `rd ≠ x0` | always |
| `010` | CSRRS rd, csr, rs1 | always | only if `rs1 ≠ x0` |
| `011` | CSRRC rd, csr, rs1 | always | only if `rs1 ≠ x0` |
| `101` | CSRRWI rd, csr, uimm | only if `rd ≠ x0` | always |
| `110` | CSRRSI rd, csr, uimm | always | only if `uimm ≠ 0` |
| `111` | CSRRCI rd, csr, uimm | always | only if `uimm ≠ 0` |
| `100` | reserved | — | → illegal |

"Reads"/"writes" refer to side effects. The read-only test for `csr[11:10] = 11` uses
the *write* column: CSRRS/CSRRC with `rs1 = x0` on a read-only CSR is legal
(that is how `rdcycle` / `rdtime` are encoded).

## 3. Access rules that Linux and OpenSBI depend on

| Rule | Why it matters |
|---|---|
| `csr[11:10] = 11` → read-only; any write → illegal | `rdtime`, `rdcycle` encodings |
| `csr[9:8]` = lowest privilege that may access it; access from a lower mode → illegal | the kernel in S-mode must trap on M-CSRs; U-mode must trap on S-CSRs |
| Unimplemented CSR → illegal | OpenSBI detects features by reading/writing CSRs under a temporary trap handler (`csr_read_allowed()` / `csr_write_allowed()` in `hart_detect_features()`, [sbi_hart.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_hart.c)). A CSR that silently reads 0 is detected as "present". |
| Counter CSRs gated by `mcounteren`/`scounteren` → illegal when clear | OpenSBI emulates `time` reads on that trap ([sbi_emulate_csr.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_emulate_csr.c)) |
| `satp` / `sfence.vma` illegal in S-mode when `mstatus.TVM = 1` | OpenSBI/hypervisors |
| WARL fields legalise on write; a CSR read returns the legal value | kernel probes `stvec` mode, `satp` mode by write-and-read-back |
| Writes that change translation/protection (`satp`, `mstatus.MPRV/SUM/MXR`, `pmpcfg/pmpaddr`, `mstatus.FS`) must affect the *next* instruction | needs a pipeline flush of younger instructions (see §5) |

## 4. What exists today

| Item | Status | Evidence |
|---|---|---|
| All six instructions, write-suppression rules | present | `Design/csr_file.sv:186-219` |
| funct3 `100` illegal | present (falls to illegal default) | `Design/opcode_decoder.sv:189` |
| Read-only space write → illegal | present | `Design/decode_stage.sv:381-386` |
| Unknown CSR → illegal (`CsrExists`) | present | `Design/csr_file.sv:139-184,224-226` |
| CSR write data from **forwarded** rs1 | present (D7 fixed) | `Design/execute_stage.sv:275` |
| CSR read forwarded from M | present (D18 fixed) | `Design/execute_stage.sv:397-404` |
| Privilege check `csr[9:8] > mode` | **missing** (no privilege register) | — |
| `mcounteren`/`scounteren` gating | **missing** | — |
| Serialization after translation-affecting CSR writes | **missing** (no such CSRs yet) | — |
| `mtval` for illegal CSR access | 0 (`(InterruptPending \|\| CsrIllegal) ? '0`) | `Design/csr_file.sv:289` |

## 5. What must change

1. **Privilege check** in `csr_file`: `CsrIllegal |= (CsrIndex[9:8] > PrivMode)`.
   Exception: the `sstatus/sie/sip` views and `time`/`cycle`/`instret` follow their
   own gating rules.
2. **Counter-enable gating** (see [ISA_ZICNTR_TIME](ISA_ZICNTR_TIME.md)).
3. **Serializing CSR writes.** Today a CSR instruction commits in EX while the
   younger instructions in D/F were fetched under the old state. That is harmless
   for `mscratch`, fatal for `satp`. Rule: a write to `satp`, `mstatus`,
   `pmpcfg*/pmpaddr*`, `menvcfg` (and `fcsr` if FS matters) flushes F/D and refetches
   at PC+4. Simplest: flush on **every** CSR write — costs two bubbles per CSR write,
   negligible for Linux.
4. **Commit point.** Once faults can come from M (MMU, PMP, bus), a CSR write in EX
   can commit *before* an older instruction in M faults → imprecise. CSR side
   effects must move to the M-stage commit (PLAN_B B5.0, and
   [modules/TRAP_COMMIT_UNIT.md](modules/TRAP_COMMIT_UNIT.md)).
5. **`mtval` = instruction bits** on illegal instruction (also required by the
   RVA20S64 `Sstvala` rule for `stval`:
   "For virtual-instruction and illegal-instruction exceptions, `stval` must be
   written with the faulting instruction",
   [rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc)).

## 6. Verification hooks

- `rv32mi-p-csr`, `rv32si-p-csr` ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)).
- The generator already emits unknown CSRs and read-only writes
  (`Python/riscv_testcase_generator.py:39-46`); extend with privilege-violation
  accesses from S/U once modes exist.
- CSR RAL: the per-register RAL (`Verification/CSR/csr_reg_block_pkg.sv`) is the
  right place to encode WARL legalisation per field; extend it with the S-mode
  views as *aliases* of the M registers (one storage, two maps), not copies.
