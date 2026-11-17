# A extension (atomics) = Zalrsc + Zaamo

Spec: Unpriv, "A" chapter, now split into
[zalrsc.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zalrsc.adoc)
(LR/SC) and [zaamo.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zaamo.adoc)
(AMOs). Hardware block: [modules/AMO_UNIT.md](modules/AMO_UNIT.md). Plan block B2.1.
Back to [index](README.md).

## 1. Required by Linux

Yes, both halves.

- Kernel march is `rv32ima`/`rv64ima`
  ([arch/riscv/Makefile](https://github.com/torvalds/linux/blob/master/arch/riscv/Makefile));
  `atomic_t`, `cmpxchg` (LR/SC loop), `xchg`, bitops (`amoor`/`amoand`) and spinlocks
  are all emitted.
- The kernel's trap return path executes a dummy `sc` to drop any dangling
  reservation (`REG_SC x0, a2, PT_EPC(sp)` in
  [arch/riscv/kernel/entry.S](https://github.com/torvalds/linux/blob/master/arch/riscv/kernel/entry.S)).
- OpenSBI requires `rv32ima`, though it now allows restricting to LR/SC with
  `rv32im_zalrsc_zicsr` ([platform_requirements.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md)).
  The kernel still needs AMOs, so implement both.

## 2. Encodings

Opcode AMO = `0101111`. Fields: `funct5[31:27] aq[26] rl[25] rs2[24:20] rs1[19:15]
funct3[14:12] rd[11:7]`. funct3 `010` = `.W`, `011` = `.D` (RV64 only; illegal on RV32).

| funct5 | Instruction | rs2 | Operation (`t = M[rs1]`) |
|---|---|---|---|
| `00010` | LR | must be `00000` (else reserved) | rd ← t; register reservation |
| `00011` | SC | src | if reservation valid and covers addr: M ← rs2, rd ← 0; else rd ← nonzero; reservation always invalidated |
| `00001` | AMOSWAP | src | rd ← t; M ← rs2 |
| `00000` | AMOADD | src | M ← t + rs2 |
| `00100` | AMOXOR | src | M ← t ^ rs2 |
| `01100` | AMOAND | src | M ← t & rs2 |
| `01000` | AMOOR | src | M ← t \| rs2 |
| `10000` | AMOMIN | src | signed min |
| `10100` | AMOMAX | src | signed max |
| `11000` | AMOMINU | src | unsigned min |
| `11100` | AMOMAXU | src | unsigned max |

Any other funct5 under `0101111` is reserved → illegal. `.W` results on RV64 are
sign-extended into `rd`; the memory op is 32-bit.

## 3. Architectural behaviour to implement

1. **Alignment.** Address not naturally aligned → address-misaligned *or*
   access-fault exception (Zalrsc/Zaamo text). Priv: "load and load-reserved
   instructions generate load exceptions, whereas store, store-conditional, and AMO
   instructions generate store/AMO exceptions"
   ([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc)).
   So LR → cause 4/5/13, SC/AMO → cause 6/7/15. `mtval` = faulting address.
   OpenSBI can't usefully emulate a misaligned LR/SC (the spec itself calls it
   impractical), so raise an **access fault** (5 / 7) to make the failure obvious and
   non-emulated. PLAN_B B2.1 already says "misaligned AMO → access fault (cause 7)".
2. **Reservation set.** One per hart. LR sets `{valid, addr}`; the set may be larger
   than the access (e.g., one cache line) but must contain all bytes accessed. SC must
   fail if its address is outside the set. Every SC invalidates the reservation.
3. **When to clear it.** The spec only requires correctness plus the forward-progress
   guarantee for *constrained* LR/SC loops (≤16 instructions, no other loads/stores
   in between). Simplest correct single-hart policy: clear on LR (re-arm), on every SC,
   on any taken trap, and on xRET. Clearing on trap is allowed ("an implementation is
   permitted to fail an SC occasionally for any reason, provided the guarantee is
   not violated"). Do **not** clear on ordinary loads/stores by this hart to other
   addresses — that would break a constrained loop only if they were inside it, which
   the constraint already forbids, but clearing on every store is a common
   over-eager bug that makes `cmpxchg` livelock when the compiler spills.
4. **Atomicity.** Single hart, no other bus masters that write RAM (no DMA): a
   blocking read-modify-write in the D-cache is atomic by construction. If a DMA
   master is ever added, the reservation must also be cleared by external writes to
   the set (Zalrsc forward-progress rule).
5. **`aq`/`rl`.** On an in-order, single-issue, blocking-cache core every memory op is
   already performed in program order, so both bits can be ignored. This stops
   being true the moment a store buffer or non-blocking cache is added.
6. **Uncached AMOs.** AMOs to MMIO (CLINT/PLIC/UART) are not needed by Linux on these
   devices. Raise an access fault for AMO/LR/SC to non-cacheable regions (PMA
   "AMONone" in Priv's PMA section) — simplest and spec-legal.
7. **Interaction with the MMU.** An AMO is a store for permission purposes: needs
   `W` (and `R`) permission and sets `D` (Svade: page fault if `A=0` or `D=0`).
8. **Interaction with PMP.** Checked as a store.

## 4. What exists today

| Item | Status | Evidence |
|---|---|---|
| AMO opcode in `opcode_t` | missing | `Design/shared_pkg.sv:21-37` |
| Decode | missing → falls to default `IllegaleInstruction = 1` | `Design/opcode_decoder.sv:69,71-203` |
| D-cache read-modify-write | missing (CPU port is read *or* write per access) | `Design/cache.sv:60-66` |
| Reservation register | missing | — |
| ISS model | missing (ISS covers I, M, Zicsr, F-subset) | `Verification/Risc/riscv_iss_pkg.sv:8-11` |
| Generator | missing | `Python/riscv_testcase_generator.py:1-25` |

## 5. What must change

| # | Change | File | Detail |
|---|---|---|---|
| 1 | `opcode_t += AMO = 7'b010_1111`; `amo_op_t` enum | `Design/shared_pkg.sv` | PLAN_B §B2.1 lists the enum |
| 2 | Decode funct5/funct3/rs2; RV32 `.D` illegal; `MemReadD=MemWriteD=1` for AMO, `MemReadD` only for LR, `MemWriteD` only for SC | `Design/opcode_decoder.sv`, `Design/decode_stage.sv` | carry `AmoOpE/M` down the pipe |
| 3 | Address = rs1 (no immediate); misaligned check in EX like loads/stores | `Design/execute_stage.sv:439-458` | note: AMOs have **no** offset; `ALUSrc` must select 0 |
| 4 | AMO ALU + reservation register | new `Design/amo_unit.sv` in `memory_stage` | see [AMO_UNIT](modules/AMO_UNIT.md) |
| 5 | D-cache RMW: hit → read, compute, write back to the same line (2 cycles), miss → refill then RMW | `Design/cache.sv` | `CPUAmoOp` port per PLAN_B §3.5 |
| 6 | SC result (0/1) and AMO old value go to `rd` via `MemToReg` path | `Design/memory_stage.sv` | `LoadDataM` mux |
| 7 | `misa.A` (bit 0) set | `Design/csr_file.sv:60-63`, `Design/csr_defs.sv:41-44` | |
| 8 | ISS: LR/SC/AMO semantics incl. reservation policy; generator emits them, incl. constrained LR/SC loops and misaligned cases | `Verification/Risc/riscv_iss_pkg.sv`, `Python/riscv_testcase_generator.py` | |

## 6. Verification hooks

- `rv32ua-p-*` / `rv64ua-p-*` ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)),
  ACT "A" suite ([riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test)).
- Directed: SC without LR fails; LR, trap, SC fails (with the chosen policy);
  LR A, SC B fails; LR, store to same addr, SC (implementation-defined: document it);
  AMO on page with `D=0` → page fault 15; AMO misaligned → cause 7, `mtval` = address.
- Note for the ISS: the reservation policy is implementation-defined, so the ISS
  must model *your* policy exactly or the cosim will diverge on SC results. I found
  no reservation clearing in Spike's `processor_t::take_trap()`
  ([riscv/processor.cc](https://github.com/riscv-software-src/riscv-isa-sim/blob/master/riscv/processor.cc),
  checked 2026-11-05), so a "clear on trap" policy will differ from Spike after a
  trap inside an LR/SC sequence. Either align the policy with Spike or let the cosim
  take the SC result from the DUT in that one case (Ibex's cosim does the same kind
  of RTL→ISS sync for interrupts and memory errors, see
  [cosim.rst](https://github.com/lowRISC/ibex/blob/master/doc/03_reference/cosim.rst)).
