# `amo_unit.sv` + reservation register + D-cache read-modify-write

Spec basis: [ISA_A](../ISA_A.md). Plan block B2.1. Back to [index](../README.md).

## 1. Purpose

Execute LR/SC and AMO*.W/.D atomically on a single in-order hart with a blocking,
write-back D-cache (`Design/cache.sv`).

## 2. Blocks

| Block | Where | Logic |
|---|---|---|
| `amo_unit` (combinational) | `memory_stage` | `NewData = f(AmoOpM, OldData, Rs2DataM)` for SWAP/ADD/XOR/AND/OR/MIN/MAX/MINU/MAXU; `.W` on RV64 operates on the addressed 32-bit lane |
| Reservation register | `memory_stage` | `ResValid`, `ResAddr[PADDR_W-1:LOG2(RES_BYTES)]` |
| Cache RMW mode | `cache.sv` | new CPU input `CPUAmo`; hit: read word, then write `NewData` with byte enables in the next cycle; miss: refill (existing FSM) then RMW |

`RES_BYTES` = reservation granule. The cache line (16 B today) or the word is
legal; RVA20 caps it at 128 B (`Za128rs`,
[rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc)).
Use the naturally aligned 8-byte doubleword (covers `.W` and `.D`).

## 3. Ports

`amo_unit`:
```
input  amo_op_t               AmoOp,
input  logic                  IsWord,        // .W
input  logic [DATA_WIDTH-1:0] OldData,       // from cache (aligned lane)
input  logic [DATA_WIDTH-1:0] SrcData,       // forwarded rs2
output logic [DATA_WIDTH-1:0] NewData
```
`cache.sv` additions (names per PLAN_B §3.5): `CPUAmo`, reuse `CPUByteEn`,
`CPUReadData` returns the *old* value; `CacheHit` stays low until the write half
completes (so the existing "freeze on miss" contract covers the extra cycle — no new
hazard signal is needed). PLAN_B names it `AmoBusyM`; folding it into `CacheHit`
is simpler and equivalent.

## 4. Behaviour

| Instr | Cache action | rd | Reservation |
|---|---|---|---|
| LR | read | loaded value (sign-extended for `.W`) | `ResValid ← 1`, `ResAddr ← addr` |
| SC | write iff `ResValid && ResAddr == addr` | 0 success / 1 failure | `ResValid ← 0` always |
| AMO | RMW | old value | unchanged |
| any trap taken, MRET, SRET | — | — | `ResValid ← 0` (policy; see [ISA_A](../ISA_A.md) §3.3) |

Faults (precise, at M, before any write): misaligned → access fault (5 for LR,
7 for SC/AMO) per the chosen policy; TLB/PMP/PMA faults as for loads (LR) and
stores (SC/AMO); AMO/LR/SC to a non-cacheable region → access fault.

## 5. Pipeline integration

- Decode: `MemReadD` for LR/AMO, `MemWriteD` for SC/AMO, `AmoOpD`, address operand =
  rs1 with immediate 0, store data = forwarded rs2 (`WriteDataE` already is the
  forwarded rs2, `Design/execute_stage.sv:217-229`).
- Write-back: AMO/LR/SC results return through the existing `MemToReg` path
  (`ReadDataW`); SC returns the 0/1 status on that path.
- Load-use hazard: AMO/LR/SC are loads for `hazard_unit` (`SelectorE == MemToReg`,
  `Design/hazard_unit.sv:87`), so a dependent instruction stalls correctly with no
  change.

## 6. Verification hooks

- `amo_unit` is small, combinational, and has a crisp spec function → exhaustively
  checkable with formal (or a one-to-one SV function in the mem predictor).
- Mem env: add AMO/LR/SC items; byte-exact flat-memory predictor already exists
  (`Verification/Memory/unused/mem_flat_predictor_pkg.sv`, which is the compiled one
  per DESIGN_VERIFICATION_CHANGES §7).
- SVA on `cache.sv`: no AXI write between the RMW read and write halves for
  another address; a miss on AMO refills exactly once.
- Full core: `rv32ua-p-*`, `rv64ua-p-*`; ISS reservation policy identical to RTL.
