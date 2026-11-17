# M extension (integer multiply / divide)

Spec: Unpriv, "M Extension for Integer Multiplication and Division"
([m-st-ext.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/m-st-ext.adoc)).
Back to [index](README.md).

## 1. Required by Linux

Yes. The kernel base march is `rv32ima` / `rv64ima`
([arch/riscv/Makefile](https://github.com/torvalds/linux/blob/master/arch/riscv/Makefile));
OpenSBI's base requirement is `rv32ima_zicsr` / `rv64ima_zicsr`
([platform_requirements.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md)).

## 2. Encodings (opcode OP `0110011` / OP-32 `0111011`, funct7 `0000001`)

| funct3 | OP | OP-32 (RV64) |
|---|---|---|
| `000` | MUL | MULW |
| `001` | MULH | reserved |
| `010` | MULHSU | reserved |
| `011` | MULHU | reserved |
| `100` | DIV | DIVW |
| `101` | DIVU | DIVUW |
| `110` | REM | REMW |
| `111` | REMU | REMUW |

Required corner semantics (no traps on division):

| Case | Quotient | Remainder |
|---|---|---|
| divide by zero | all ones (−1 signed, 2^XLEN−1 unsigned) | dividend |
| signed overflow `MIN / −1` | `MIN` | 0 |

`*W` forms operate on the low 32 bits and sign-extend the 32-bit result, including
DIVUW/REMUW (the *result* is sign-extended even though the operation is unsigned).

## 3. What exists today

| Item | Status | Evidence |
|---|---|---|
| Decode of all 8 ops and RV64 `*W` subset (MULH* on OP-32 illegal) | present | `Design/alu_decoder.sv` (funct7 `0000001` branch, `WordOp` check) |
| Single-cycle combinational multiplier (Wallace tree) and non-restoring divider | present | `Design/risc_alu.sv:70-81`; `Design/wallace_tree.sv`; `Design/non_restoring_divider.sv` |
| Div-by-zero / overflow handling, WIDTH-safe | present (D30 fixed) | `Design/non_restoring_divider.sv`; DESIGN_VERIFICATION_CHANGES §3.9 |
| RV64 operand conditioning for DIVUW/REMUW (zero-extend inputs) | present | `Design/execute_stage.sv:368-380` |

## 4. What must change

Functionally nothing for Linux. Two engineering points:

1. **Timing.** A combinational 64×64 multiply and 64-bit divide in one cycle
   (PLAN_B Appendix A9) is fine for simulation, unusable for FPGA/ASIC timing. If the
   SoC is ever put on an FPGA for faster Linux boots (PLAN_B B8.5), the divider must
   become multi-cycle. The FPU already has the blocking "hold EX until done" pattern
   (`Design/hazard_unit.sv:96`, `FPUStall`); a multi-cycle divider should reuse that
   exact request/stall contract instead of adding a new one.
2. **Verification at XLEN = 64.** The `*W` paths have never been run (see
   [ISA_RV_BASE](ISA_RV_BASE.md) §3).

## 5. Verification hooks

- `rv32um-p-*`, `rv64um-p-*` from [riscv-tests](https://github.com/riscv-software-src/riscv-tests).
- Directed corner list: `0/0`, `x/0`, `MIN/−1`, `MIN%−1`, `MULHSU` with negative rs1 and
  rs2 ≥ 2^(XLEN−1), `DIVUW` with bit 31 set.
