# Cache maintenance, uncached path and bus-error reporting (`cache.sv` extensions)

Spec basis: [ISA_ZIFENCEI](../ISA_ZIFENCEI.md), Priv "Physical Memory Attributes"
([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc)).
Plan blocks B2.0, B7.2. Back to [index](../README.md).

## 1. Purpose

`cache.sv` is a solid L1 (set-associative, true LRU, write-back/write-allocate, AXI4
burst master, byte enables — `Design/cache.sv:1-41`). Linux needs four things it
does not have:

| Need | Why | Today |
|---|---|---|
| D-cache **flush all** (write back dirty lines) | FENCE.I must make stores visible to fetch | no port |
| I-cache **invalidate all** | FENCE.I | no port |
| **Uncached** single-beat access | CLINT/PLIC/UART registers must never be cached, read twice, or burst-filled; a UART RBR read pops a byte | every access is cacheable; a miss always fetches a full line (`Design/cache.sv:535-544`, `MARLen = LINE_WORDS-1`) |
| **Bus-error → access fault** | holes in the address map, ROM writes, PMA violations | on a non-`OKAY` refill the line is left invalid, the FSM returns to IDLE and the CPU re-requests — infinite retry, nothing reaches the pipeline (`Design/cache.sv:600-630`) |

## 2. Ports added (PLAN_B §3.5 names)

```
input  logic CPUUncached,      // from pma.sv: Cacheable(PA) == 0
input  logic CPUFlushAll,      // D-cache: write back every dirty line, keep lines valid
input  logic CPUInvalidateAll, // I-cache: clear every valid bit
output logic CPUFlushDone,     // one-cycle pulse when the maintenance op completes
output logic CPUBusError       // the access completed with SLVERR/DECERR
```

`CacheHit` keeps its meaning "0 = pipeline must stall", so maintenance and uncached
accesses need no new hazard signal: hold `CacheHit` low until done.

## 3. Behaviour

**Flush (D-cache).** New FSM state(s) in the existing `axi_state_t` style
(`Design/shared_pkg.sv:332-339`): walk `set = 0..SETS-1`, `way = 0..WAY-1`; for each
valid+dirty line issue the existing write-back burst, clear dirty. 32 lines today,
so the walk is short. A simpler legal alternative: invalidate after write-back
(costs refills afterwards, not correctness).

**Invalidate (I-cache).** Clear all `valid` bits in one cycle (they are flops).

**Uncached read/write.** Bypass tag lookup and allocation: one AXI beat, `xLen = 0`,
`xSize` = access size, write strobe = `CPUByteEn`. Read data returned directly with
a one-cycle `CacheHit` pulse (same "read-through" mechanism already used for refills,
`Design/cache.sv:21-27`).

**Bus error.** On `RRESP`/`BRESP` ∉ {OKAY, EXOKAY}: complete the access (don't retry),
do not validate the line, pulse `CPUBusError`. The stage converts it into an
exception on the requesting instruction: fetch → cause 1, load → 5, store/AMO → 7,
`tval` = virtual address. A write-back of a dirty victim that errors is not
attributable to any instruction; raise nothing to the pipeline and log it
(SVA/TB error) — it means the address map is broken.

**PMA rule.** Instruction fetch from a non-executable/non-cacheable region (e.g.,
UART) → instruction access fault (1) without issuing the read.

## 4. Pipeline integration

| Event | Who drives | Effect |
|---|---|---|
| FENCE.I commits at M | `memory_stage` raises `CPUFlushAll` on DCache, then `CPUInvalidateAll` on ICache after `CPUFlushDone` | `hazard_unit` freezes until done; then F/D/E flushed, refetch at PC+4 |
| Uncached load/store | `pma.sv` on the translated PA | freeze until the single beat completes |
| `CPUBusError` | cache → stage | `ExcValidX` set on that instruction (requires commit at M, [TRAP_COMMIT_UNIT](TRAP_COMMIT_UNIT.md)) |

Ordering note: with uncached MMIO, a blocking single-issue core already performs
MMIO accesses in program order, so `FENCE` with I/O bits can stay a NOP.

## 5. Verification hooks

- `Verification/Memory/cache_sva.sv` already binds into both caches with an
  independent LRU reference. Add:
  - after `CPUFlushDone`: no line valid ∧ dirty;
  - after invalidate: no line valid;
  - `CPUUncached` access: no tag/valid/data array write, AXI `xLen == 0`;
  - non-OKAY response: no line becomes valid; `CPUBusError` pulses exactly once.
- `Verification/Protocol/axi_random_stall.sv` exists but is **not bound anywhere**
  (`grep` finds only its own definition); use it to randomise latency during flush
  and uncached traffic.
- Memory model: add an error-injection knob (respond `SLVERR` at configured
  addresses) — prerequisite for testing access faults at all.
