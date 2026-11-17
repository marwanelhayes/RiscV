# RV32I / RV64I base integer ISA

Spec: Unpriv, chapters "RV32I Base Integer Instruction Set" and "RV64I Base Integer
Instruction Set" ([base.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/base.adoc),
[rv64.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/rv64.adoc)).
Back to [index](README.md).

## 1. Required by Linux

The kernel is compiled with `-march=rv32ima…` or `rv64ima…`
([arch/riscv/Makefile](https://github.com/torvalds/linux/blob/master/arch/riscv/Makefile)),
so every base instruction can appear. Userspace (BusyBox/musl/glibc) is compiled by
the same toolchain, so the same holds there.

## 2. Instruction set (encodings)

| Group | Opcode `[6:0]` | Instructions | funct3 / funct7 notes |
|---|---|---|---|
| LUI | `0110111` | LUI | U-imm `[31:12]` |
| AUIPC | `0010111` | AUIPC | rd = PC + (U-imm) |
| JAL | `1101111` | JAL | J-imm, bit 0 implicit 0; target = **PC** + imm |
| JALR | `1100111` | JALR | funct3 = `000` only; target = (rs1 + imm) & ~1 |
| BRANCH | `1100011` | BEQ BNE BLT BGE BLTU BGEU | funct3 `000 001 100 101 110 111`; `010`/`011` reserved |
| LOAD | `0000011` | LB LH LW LBU LHU (+ LWU, LD on RV64) | funct3 `000 001 010 100 101` (+ `110`, `011`) |
| STORE | `0100011` | SB SH SW (+ SD on RV64) | funct3 `000 001 010` (+ `011`) |
| OP-IMM | `0010011` | ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI | shamt is 5 bits (RV32) / 6 bits (RV64); `imm[5]=1` on RV32 shifts is reserved |
| OP | `0110011` | ADD SUB SLL SLT SLTU XOR SRL SRA OR AND | funct7 `0000000` / `0100000` |
| OP-IMM-32 (RV64) | `0011011` | ADDIW SLLIW SRLIW SRAIW | 32-bit op, result sign-extended |
| OP-32 (RV64) | `0111011` | ADDW SUBW SLLW SRLW SRAW | same |
| MISC-MEM | `0001111` | FENCE (funct3 `000`), FENCE.TSO, PAUSE (both are FENCE encodings) | FENCE.I is funct3 `001` → see [ISA_ZIFENCEI](ISA_ZIFENCEI.md) |
| SYSTEM | `1110011` | ECALL, EBREAK (+ privileged and Zicsr) | see [PRIV_ARCH](PRIV_ARCH.md), [ISA_ZICSR](ISA_ZICSR.md) |

Architectural rules that matter for Linux:

- The all-zero 32-bit word must be illegal (it is not a valid encoding in any
  extension). The kernel and OpenSBI rely on illegal-instruction traps for feature
  detection.
- `x0` reads as zero and ignores writes.
- Misaligned loads/stores: the spec allows hardware to either perform them or raise
  an address-misaligned (or access-fault) exception. OpenSBI emulates misaligned
  loads/stores in M-mode (`lib/sbi/sbi_trap_ldst.c` in
  [OpenSBI](https://github.com/riscv-software-src/opensbi)), so trapping is
  functionally acceptable but costs thousands of cycles each.
- Instruction-address-misaligned is raised on the *taken* branch/jump, with
  `mtval` = target (IALIGN = 32 until C is added).

## 3. What exists today

| Feature | Status | Evidence |
|---|---|---|
| All RV32I opcodes incl. LUI/AUIPC/FENCE | present | `Design/shared_pkg.sv:21-37`; `Design/opcode_decoder.sv:71-203` |
| Standard B/J immediates, `target = PC + imm` | present (the old ×4 dialect is gone) | `Design/decode_stage.sv:363-376` |
| JALR `(rs1+imm) & ~1`, funct3 check | present | `Design/execute_stage.sv:410`; `Design/opcode_decoder.sv:166-175` |
| Shift-immediates with 5/6-bit shamt legality | present | `Design/alu_decoder.sv` (`ShiftFunct7`, I-type `3'b001`/`3'b101`) |
| Sub-word loads/stores, sign/zero extension, byte enables | present | `Design/memory_stage.sv:135-171` |
| RV64 W-ops, LD/SD/LWU (`+define+XLEN=64`) | present in RTL, **not regressed** | `Design/opcode_decoder.sv:122-139`; `Design/execute_stage.sv:364-394`; `Questa/do/compile.do` has no XLEN define |
| Reserved funct3/funct7 → illegal | present | `Design/opcode_decoder.sv:88-111,174,179`; `Design/alu_decoder.sv` (`Illegal`) |
| FENCE | NOP; `fm/pred/succ/rs1/rd` ignored (correct: FENCE.TSO and PAUSE are accepted) | `Design/opcode_decoder.sv:177-180` |
| Misaligned load/store/target → trap with `mtval` | present | `Design/execute_stage.sv:426-458` |
| Illegal instruction `mtval` | writes 0 (allowed by Priv; see §4) | `Design/execute_stage.sv:421-425` |
| Reset PC | `0` | `Design/wb_stage.sv:70-73` |
| PC width | XLEN | `Design/wb_stage.sv:48` |

## 4. Corner cases to check (all are ISA-level, so the ISS checker can cover them)

1. AUIPC uses the PC of the AUIPC itself (`PCE = PCPlus4E - 4`,
   `Design/execute_stage.sv:366,409`). Correct today; must stay correct when C makes
   `PCPlus4` wrong for 2-byte instructions — carry `PCX` instead (see [ISA_C](ISA_C.md)).
2. JALR with `rd == rs1`: the link write must not corrupt the target. Today the
   target comes from the forwarded `SrcAE` in EX before write-back — correct.
3. Branch taken to a misaligned target: exception on the branch, no redirect, no
   `rd` write (JAL/JALR). Checked by `TrapsE` priority `Design/execute_stage.sv:426-430`.
4. RV64: `SLLIW` with `imm[5] = 1` is reserved; `SRAIW` sign-extends from bit 31;
   `ADDIW rd, rs, 0` is `sext.w`. Covered by `Design/alu_decoder.sv` `WordOp` logic,
   but **no 64-bit run exists**.
5. `mtval` on illegal instruction. Priv allows 0
   ([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc),
   "mtval is either set to zero or written with exception-specific information").
   OpenSBI copes: if `tval` is 0 it re-reads the instruction from `mepc` using an
   MPRV load (`sbi_illegal_insn_handler()` in
   [sbi_illegal_insn.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_illegal_insn.c)).
   That makes **MPRV a hard dependency** (see [PRIV_ARCH](PRIV_ARCH.md)). Writing the
   instruction bits into `mtval` is cheap (carry `InstructionD` to EX) and removes an
   extra fetch per emulated instruction — recommended.

## 5. What must change for Linux

| # | Change | Where | Plan |
|---|---|---|---|
| 1 | Reset vector becomes a parameter (`RESET_VECTOR = 0x1000`) | `Design/wb_stage.sv:72` | B7.7 |
| 2 | Physical address width 32 (RV32) / ≥ 34–56 (RV64 Sv39) instead of 12 | `Design/shared_pkg.sv:365` | B7.1 |
| 3 | Illegal-instruction `mtval` = instruction bits (recommended) | `Design/execute_stage.sv:422-425`, `Design/csr_file.sv:289` | B1.6 follow-up |
| 4 | Run the full regression at `XLEN=64` before building anything on top | `Questa/do/compile.do` | B1.1 exit gate |
| 5 | Optional: hardware misaligned loads/stores (avoids OpenSBI emulation cost in sim) | `memory_stage`/`cache` | not planned; only if boot time hurts |

## 6. Verification hooks

- `riscv-tests` `rv32ui-p-*` / `rv64ui-p-*` (physical) and later `-v-*` (virtual)
  ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)).
- RISC-V Architectural Certification Tests for I
  ([riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test); ACT4 framework).
- The in-house ISS (`Verification/Risc/riscv_iss_pkg.sv`) already models RV32I/RV64I;
  it needs an independent cross-check against Spike or Sail (see
  [../verification/COMPARISON.md](../verification/COMPARISON.md)).
