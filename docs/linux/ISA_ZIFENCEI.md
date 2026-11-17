# Zifencei (FENCE.I)

Spec: Unpriv "Zifencei"
([zifencei.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zifencei.adoc)).
Hardware: [modules/CACHE_MAINTENANCE.md](modules/CACHE_MAINTENANCE.md). Plan block B2.0.
Back to [index](README.md).

## 1. Required by Linux

Yes.
- The kernel march string ends in `_zicsr_zifencei` with binutils ≥ 2.36 / GCC ≥ 12
  (`TOOLCHAIN_NEEDS_EXPLICIT_ZICSR_ZIFENCEI` in
  [arch/riscv/Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig)).
- The kernel executes `fence.i` after writing code (module loading, alternatives
  patching, ftrace, kprobes, and — always — when user pages are mapped executable,
  via `flush_icache_*`), and the ELF loader writes user programs with stores before
  they are fetched.
- RVA20S64 mandates Zifencei "as it is the only standard way to support
  instruction-cache coherence"
  ([rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc)).

## 2. Encoding and semantics

`imm[11:0]=0 | rs1=0 | funct3=001 | rd=0 | opcode=0001111`.

The unused fields (`imm`, `rs1`, `rd`) are reserved for finer-grain fences; base
implementations **ignore** them (do not trap on non-zero values).

Semantics: after FENCE.I, instruction fetches on this hart observe every store
this hart made before the FENCE.I. Nothing about other harts (they need an IPI +
their own FENCE.I; for SMP Linux this goes through SBI `remote_fence_i`).

## 3. What exists today

| Item | Status | Evidence |
|---|---|---|
| Decode | **illegal** (`MISC_MEM` accepts only funct3 `000`) | `Design/opcode_decoder.sv:177-180` |
| Generator | emits FENCE.I as an *illegal* test | `Python/riscv_testcase_generator.py:328` |
| I-cache invalidate | missing | `Design/cache.sv` has no invalidate input |
| D-cache write-back flush | missing (write-back, write-allocate policy; dirty lines only leave on eviction) | `Design/cache.sv:21-33` |
| Memory organisation | Harvard: separate I and D memories, so stores can never become visible to fetch at all | `Verification/Risc/risc_top.sv` (`InstrMem`, `DataMem`) |

The last row is the real blocker: until the SoC has one RAM behind an interconnect
([modules/AXI_INTERCONNECT_MEMORY_MAP.md](modules/AXI_INTERCONNECT_MEMORY_MAP.md)),
FENCE.I cannot even be defined in this system.

## 4. What must change

1. Decode `funct3 = 001` under MISC-MEM as `FenceID` (ignore imm/rs1/rd).
2. FENCE.I is **serializing**: when it commits, flush F/D (and E if commit moves to
   M), then
   1. D-cache: write back every dirty line (`CPUFlushAll`, wait `CPUFlushDone`),
   2. I-cache: invalidate every line (`CPUInvalidateAll`, one cycle if `valid` is a
      flop array),
   3. refetch at `PC + 4`.
3. Hazard unit gets a request `FenceIBusyM` that freezes the pipeline like a miss.

Cheaper alternatives, in order of simplicity:

| Option | Cost | Caveat |
|---|---|---|
| A. Write-back + invalidate as above | one FSM state in `cache.sv` that walks all sets | Flushing 32 lines is trivial at this cache size |
| B. Make the D-cache write-through for the first boot (no dirty lines) + I-cache invalidate | changes D-cache policy, more AXI traffic | FENCE.I becomes "invalidate I-cache only" |
| C. Snooping I-cache | way more logic | not justified for one hart |

Option A matches PLAN_B B2.0; keep it.

## 5. Verification hooks

- `rv32ui-p-fence_i` / `rv64ui-p-fence_i`
  ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)).
- Directed self-modifying code: store a new instruction over one already in the
  I-cache, FENCE.I, jump to it; and the negative case without FENCE.I (behaviour is
  allowed to be stale — the ISS must not *require* staleness, so mask that case).
- SVA on `cache.sv`: after `CPUFlushDone`, no line is both valid and dirty; after
  invalidate, no line is valid.
