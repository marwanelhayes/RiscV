# Cache maintenance, uncached path and bus-error reporting (`cache.sv` extensions)

Spec basis: [ISA_ZIFENCEI](../ISA_ZIFENCEI.md), Priv "Physical Memory Attributes"
([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc)).
Plan blocks B2.0, B7.2. Back to [index](../README.md).

## 1. Purpose

`cache.sv` is a solid L1 (set-associative, true LRU, write-back/write-allocate, AXI4
burst master, byte enables — `Design/cache.sv:1-41`). The Linux plan tracks four cache features.

| Need | Why | Today |
|---|---|---|
| D-cache **flush all** (write back dirty lines) | FENCE.I must make stores visible to fetch | Implemented with `CPUFlushAll` and `CPUFlushDone` |
| I-cache **invalidate all** | FENCE.I | Implemented with `CPUInvalidateAll` and `CPUInvalidateDone` |
| **Uncached** single-beat access | CLINT/PLIC/UART registers must never be cached, read twice, or burst-filled; a UART RBR read pops a byte | every access is cacheable; a miss always fetches a full line (`Design/cache.sv:535-544`, `MARLen = LINE_WORDS-1`) |
| **Bus-error → access fault** | holes in the address map, ROM writes, PMA violations | write-back (`BRESP`) error: completed as written back, line clean, nothing raised; `cache_sva` reports `SVA_CACHE_BERR` (`Design/cache.sv` `AXI_WR_RESP`). Refill (`RRESP`) error, B7.2: the line is left invalid, the FSM returns to IDLE and the CPU re-requests, so it retries forever and nothing reaches the pipeline (`Design/cache.sv` `AXI_RD_DATA`) |

## 2. Ports added (PLAN_B §3.5 names)

```
input  logic CPUUncached,      // from pma.sv: Cacheable(PA) == 0
input  logic CPUFlushAll,      // D-cache: write back every dirty line, keep lines valid
input  logic CPUInvalidateAll, // I-cache: clear every valid bit
output logic CPUFlushDone,     // one-cycle pulse when the flush completes
output logic CPUInvalidateDone, // one-cycle pulse after invalidation
output logic CPUBusError       // the access completed with SLVERR/DECERR
```

A cache deasserts `CacheHit` during its maintenance operation. MEM holds
`FenceIBusyM` across both operations until the instruction cache acknowledges
invalidation.

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

- `Verification/Memory/cache_sva.sv` checks every set and way for a clean
  D-cache at flush completion and an empty I-cache at invalidate completion.
- Planned B7.2 checks cover single-beat uncached accesses without allocation
  and a single `CPUBusError` pulse on a failed access.
- `Verification/Protocol/axi_random_stall.sv` sits between the D-cache and shared
  RAM in `risc_top`. Set `+AXI_STALL_PCT` to exercise delayed flush traffic.
- Error injection: `+AXI_BRESP_ERR_PCT=<n>` on `axi_random_stall` (in `mem_top` and
  `risc_top`) turns n% of write responses into `SLVERR`. `mem_berr_test`
  (`+AXI_BRESP_ERR_PCT=<n> +MEM_FENCEI`) expects the `SVA_CACHE_BERR` reports and
  checks the line is clean after each write-back. Refill (`RRESP`) injection is still
  open for B7.2.
