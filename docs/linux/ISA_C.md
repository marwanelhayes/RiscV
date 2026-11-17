# C extension (compressed instructions)

Spec: Unpriv "C" chapter, now defined as Zca (+ Zcf/Zcd)
([c-st-ext.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/c-st-ext.adoc),
[zca.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zca.adoc)).
Plan block B9.2. Back to [index](README.md).

## 1. Is it required?

Not for booting, but every default points at it:

| Fact | Source |
|---|---|
| `CONFIG_RISCV_ISA_C` defaults to `y` and "produces a kernel that will not run on systems that do not support compressed instructions" | [arch/riscv/Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig) |
| The RVA20U64 application profile (what distributions target) mandates M, A, F, D, **C**, Zicsr, Zicntr; RVA20S64 adds Zifencei, Sv39, Svade, Sstvala | [profiles/rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc) |

So: first boot with `CONFIG_RISCV_ISA_C=n` and a Buildroot userland built for
`rv32ima`/`rv64ima`. Any prebuilt distro (Debian/Fedora riscv64) needs RV64GC,
i.e. C **and** F+D (see [ISA_F_D](ISA_F_D.md)).

## 2. What C changes architecturally

1. **IALIGN = 16.** Instructions may start at any 2-byte boundary; a 32-bit
   instruction can straddle a 4-byte word, a cache line and a page.
2. **Instruction-address-misaligned** can then only occur for `target[0] = 1`, which
   JALR already clears and B/J immediates cannot produce — in practice it disappears.
   `mepc[1]`/`sepc[1]` become writable (today `Design/csr_file.sv:286,315` force
   `mepc[1:0] = 00`, which becomes wrong).
3. **Link value** = PC + 2 for C.JAL / C.JALR.
4. **Fetch fault on the second half** of a straddling instruction: `mtval`/`stval`
   = address of the faulting half (Priv text on instruction page/access faults).
5. **Illegal RVC encodings**, including the all-zero halfword, raise illegal
   instruction.
6. **XLEN-dependent encodings**: C.JAL and C.FLW/C.FSW on RV32 vs C.ADDIW, C.LD/C.SD
   on RV64 (same quadrant/funct3 slots).

## 3. What exists today

| Item | Status | Evidence |
|---|---|---|
| Fetch | 4-byte PC increment, one 32-bit instruction per access | `Design/fetch_stage.sv:112-117` (`pc_adder`), `:95-110` |
| PC of an instruction | reconstructed as `PCPlus4 - 4` in decode and execute | `Design/decode_stage.sv:374`; `Design/execute_stage.sv:409` |
| `mepc`/`mtvec` alignment | `mepc[1:0]` forced 0 | `Design/csr_file.sv:286,315` |
| Misaligned-target check | `PCTargetE[1]` | `Design/execute_stage.sv:426` |

Every `PCPlus4X − 4` reconstruction is wrong for a 2-byte instruction. This is the
main hidden cost of C in this pipeline.

## 4. What must change (if C is added)

| # | Change | Where |
|---|---|---|
| 1 | Carry the real `PCX` (not just `PCPlus4X`) through every pipeline register; link value = `PC + (IsCompressed ? 2 : 4)` | every stage register; PLAN_B §2.3 already requires `PCX` for the M-stage commit |
| 2 | Fetch aligner with a 16-bit holding buffer; two I-cache accesses (and two translations after the MMU) for straddling instructions | `Design/fetch_stage.sv` |
| 3 | Combinational expander RVC → RV32/RV64 32-bit encoding before IF/ID, so decode is unchanged | new `Design/c_expander.sv` |
| 4 | `mepc[1]`, `sepc[1]` writable; `misa.C` (bit 2) | `Design/csr_file.sv` |
| 5 | Illegal RVC (incl. `0x0000`) → illegal with `mtval` = 16-bit encoding (if `mtval` holds instruction bits) | expander |

## 5. Trade-off

| For | Against |
|---|---|
| 25–30 % smaller code (PLAN_B estimate; not re-measured here) → fewer I-cache misses, faster sim boot | Touches fetch, every stage register (PC), CSR alignment, and the MMU fetch path |
| Runs stock RV64GC binaries (with F+D) | Straddling-instruction × page-fault × interrupt corner cases are a classic source of core bugs (riscv-dv has dedicated generators for compressed streams) |
| Kernel default config works unchanged | Zero value for the first Linux shell |

Recommendation: keep it after the first shell as PLAN_B says. Do the `PCX`
plumbing (item 1) in B5.0 anyway, because the commit-at-M work needs it; that
removes the biggest C cost later.

## 6. Verification hooks

- `rv32uc-p-*`, `rv64uc-p-*` ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)).
- [riscv-dv](https://github.com/chipsalliance/riscv-dv) supports RV32IMAFDC/RV64IMAFDC
  random streams with compressed instructions.
- Directed: 32-bit instruction straddling a page boundary where the second page is
  unmapped (fault `tval` = second-page address); interrupt taken between the two
  fetches.
