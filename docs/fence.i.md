# FENCE.I review report

**B2.0 met its exit criteria on RV32 and RV64.** After the hart stores new instructions and executes `FENCE.I`, it fetches the updated instructions. Code review and the decision to commit and push remain with the repository owner. [Linux plan, B2.0](PLAN_B_LINUX.md#b20-fencei-zifencei--moved-here-from-the-old-phase-1)

## Implementation

The decoder recognizes MISC-MEM funct3 `001` and ignores the reserved immediate and register fields. An accepted fence squashes younger instructions. MEM holds the pipeline while the D-cache writes back each valid dirty line and waits for its AXI write response. The I-cache then drains any outstanding refill and clears its valid bits. Fetch restarts at the fence’s saved `PC+4`. The full-core testbench connects both AXI ports to the same 4 KiB RAM so write-backs are visible to fetch. [ISA notes](linux/ISA_ZIFENCEI.md) · [MEM sequencing](../Design/memory_stage.sv) · [Cache RTL](../Design/cache.sv) · [Full-core bench](../Verification/Risc/risc_top.sv)

## Verification results

| Check | RV32 | RV64 |
|---|---|---|
| Upstream `fence_i` with 40% AXI stall probability | Pass, 338 commits | Pass, 338 commits |
| Directed self-modifying code with 40% AXI stall probability | Pass, 43 commits | Pass, 43 commits |
| Random full-core program, seed 1234 | Pass, 454 commits | Pass, 457 commits |
| Fetch, decode, execute, memory, write-back and hazard benches, seed 111 | 6/6 passed | 6/6 passed |
| Yosys structural check | 0 problems | 0 problems |

The three full-core runs on each width reported zero ISS or Spike mismatches. Both FENCE.I programs wrote `tohost = 1`. The directed program warms and patches two cached instructions, including the one at the fence’s `PC+4`. Its pre-fence probe accepts either encoding. In a separate RV32 control run, replacing the required fence with a NOP triggered a mismatch on the first stale post-fence result. [Directed assembly](../Verification/Compliance/fence_i_smc.S) · [Verification plan](../Verification/VPLAN.md#zifencei)

To rerun the upstream and directed tests on both widths from the repository root, use `Questa/regress.sh -t "" -f`.

## Remaining work and limits

- **Broader regression in progress.** The post-change run covers all nine Questa benches with seeds `1234`, `111`, and `2026`, followed by the full ISA compliance suite on each width. [RV32 local run log](../Questa/Scratch/full-fencei.rFQc8X/rv32.log) · [RV64 local run log](../Questa/Scratch/full-fencei.rFQc8X/rv64.log)
- **Bus-error handling.** A failed AXI write-back (`BRESP` = `SLVERR`/`DECERR`) no longer stalls the fence. The D-cache completes it like an `OKAY` write-back, so the line is clean and the refill or flush walk continues, and nothing is raised to the pipeline. `cache_sva` reports each failure as an `SVA_CACHE_BERR` error, so a run that hits one fails. To inject failures, use `+AXI_BRESP_ERR_PCT=<n>` on `axi_random_stall`. `mem_berr_test` (with `+MEM_FENCEI`) and full-core FENCE.I runs cover this case. Refill errors (`RRESP`) still retry forever until B7.2 turns them into access faults. [Cache maintenance spec](linux/modules/CACHE_MAINTENANCE.md) · [Cache RTL](../Design/cache.sv)
- **Hardware and Linux validation.** Timing closure and a Linux boot remain untested. A hardware integration must route instruction fetches and data write-backs for writable executable addresses to the same physical memory.
