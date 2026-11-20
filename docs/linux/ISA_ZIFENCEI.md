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

## 3. Implementation

The decoder recognizes MISC-MEM funct3 `001` and ignores the reserved operands.
An accepted fence clears the younger pipeline stages and enters MEM. An
interrupt or exception that redirects the fence in EX suppresses maintenance.

1. MEM pulses `CPUFlushAll`. The D-cache finishes outstanding AXI traffic,
   scans all sets and ways, and writes each valid dirty line back to memory.
   Cleaned lines stay valid.
2. On `CPUFlushDone`, MEM pulses `CPUInvalidateAll`. The I-cache drains
   any outstanding refill before clearing its valid bits.
3. `FenceIBusyM` holds the pipeline until `CPUInvalidateDone`. Fetch then
   restarts at the saved `PCPlus4M`.

The processor exposes separate instruction and data AXI ports. Both ports
must reach the same physical RAM for writable executable addresses. The
full-core testbench arbitrates read bursts to a single 4 KiB RAM and routes
D-cache write-backs to that RAM.

## 4. Verification hooks

- `rv32ui-p-fence_i` / `rv64ui-p-fence_i`
  ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)).
- Directed self-modifying code: store a new instruction over one already in the
  I-cache, FENCE.I, jump to it; and the negative case without FENCE.I (behaviour is
  allowed to be stale — the ISS must not *require* staleness, so mask that case).
- SVA on `cache.sv`: after `CPUFlushDone`, no line is both valid and dirty; after
  invalidate, no line is valid.
