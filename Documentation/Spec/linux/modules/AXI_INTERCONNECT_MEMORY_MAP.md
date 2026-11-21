# `axi_interconnect.sv`, `pma.sv` and the physical memory map

Spec basis: Priv "Physical Memory Attributes" (PMA)
([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc));
AXI4 protocol (Arm IHI 0022 — not fetched in this audit; the repo's
`Verification/Protocol/AXI_Assertions.sv` encodes the rules it uses).
Plan blocks B7.1, B7.2. Back to [index](../README.md).

## 1. Purpose

Today the core has **two private AXI masters wired straight to two private 4 KiB
memories** (`Design/riscv_processor.sv:46-114`; `FINAL_ADDR_WIDTH = 12`,
`Design/shared_pkg.sv:365`; `InstrMem`/`DataMem` in `Verification/Risc/risc_top.sv`).
Linux needs one physical address space where:

- code and data live in the **same** RAM (the kernel loads user programs with stores
  and then fetches them; OpenSBI's payload is data to the loader, code to the core);
- RAM is ≥ 32 MiB (Buildroot + initramfs kernels are several MiB);
- MMIO devices sit at fixed addresses, uncached.

## 2. Memory map (copy of QEMU `virt`, so the device tree and OpenSBI generic just work)

Checked against `virt_memmap[]` in QEMU
([hw/riscv/virt.c](https://github.com/qemu/qemu/blob/master/hw/riscv/virt.c)) on 2026-11-05:

| Region | Base | Size | PMA | Notes |
|---|---|---|---|---|
| Boot ROM (QEMU "MROM") | `0x0000_1000` | 4 KiB (QEMU reserves `0xF000`) | cacheable, executable, read-only | reset vector, see [BOOT_ROM_SOC_TOP](BOOT_ROM_SOC_TOP.md) |
| Test/finisher (`sifive,test0`) | `0x0010_0000` | 4 KiB | uncached, not executable | **optional but very useful in sim**: a write ends the simulation with pass/fail |
| CLINT | `0x0200_0000` | 64 KiB | uncached, no execute, no AMO | [CLINT](CLINT.md) |
| PLIC | `0x0C00_0000` | 64 MiB window (`VIRT_PLIC_SIZE`) | uncached | [PLIC](PLIC.md) |
| UART0 (ns16550a) | `0x1000_0000` | 256 B | uncached, byte access | IRQ 10 (`UART0_IRQ = 10`, [virt.h](https://github.com/qemu/qemu/blob/master/include/hw/riscv/virt.h)) — [UART_16550](UART_16550.md) |
| DRAM | `0x8000_0000` | 32–128 MiB | cacheable, executable, AMO, LR/SC | OpenSBI at `0x8000_0000`, kernel at `0x8040_0000` on RV32 (4 MiB aligned) / `0x8020_0000` on RV64 (2 MiB) |
| everything else | — | — | — | `DECERR` → access fault |

Physical address width: 32 bits covers this map on both XLENs. Sv32 allows a 34-bit
PA; capping at 32 is legal because the PTW raises an access fault for PPN bits above
the implemented PA (PLAN_B §2.2 already decided this).

## 3. `axi_interconnect.sv`

| Item | Spec |
|---|---|
| Masters | 2: I-cache master, D-cache master (PTW shares the D master) |
| Slaves | 5–6: ROM, (test), CLINT, PLIC, UART, DRAM; plus an internal DECERR slave for holes |
| Arbitration | fixed priority D > I. Safe because the core is blocking: while D waits, F is frozen and cannot issue |
| Decode | combinational on `AWADDR`/`ARADDR`, one-hot select per §2 |
| Ordering | one outstanding transaction per master (the caches never issue more), so no ID remapping/reorder buffer is needed |
| Port names | `MAW*/MW*/MB*/MAR*/MR*` on the master side, the same names on slave ports (PLAN_B §3.1) |
| Slave template | every slave has the port list of `Design/risc_data_memory.sv` so the interconnect instantiates them uniformly |

`ponytail:` single-outstanding, fixed priority — adequate for one in-order hart;
add per-ID routing and round-robin only if a DMA master or a second hart is added.

## 4. `pma.sv`

```
input  logic [PADDR_W-1:0] PAddr,
output logic Cacheable, Executable, AmoOk, Exists
```

One `always_comb` lookup of the §2 table. Used by:
- fetch: `!Executable || !Exists` → instruction access fault (1) without a bus request;
- data: `!Cacheable` → `CPUUncached`; AMO/LR/SC with `!AmoOk` → access fault 7/5;
- PTW: PTEs must be in cacheable RAM (Ssccptr: "Main memory regions with both the
  cacheability and coherence PMAs must support hardware page-table reads",
  [rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc));
  PTE outside RAM → access fault.

## 5. DRAM model

`Design/risc_data_memory.sv` is a flat array with `DEPTH = 2**(ADDR_WIDTH-BYTE_OFF_W)`
(`:55-58`); at 64 MiB that is 16 M words — fine for Verilator, heavy for Questa.
PLAN_B B7.7 recommends a sparse associative array in the **testbench**; keep the
synthesizable model in `Design/` and swap the RAM in the SoC TB top, so `Design/`
stays free of sim-only constructs.

Image loading: the I-memory model loads `$readmemb` of one 32-bit word per line
(`Design/risc_instruction_memory.sv:82`). For Linux, load one `fw_payload.bin`
(OpenSBI + kernel + DTB) at `0x8000_0000` with `$readmemh` from an ELF→hex script
(PLAN_B B0.1 `elf2hex.py`), or via a DPI loader.

## 6. Verification hooks

- `Verification/Protocol/AXI_Assertions.sv` (17 `assert property`) is bound only in
  `fetch_top` and `mem_top` (`Verification/Fetch/fetch_top.sv:96`,
  `Verification/Memory/mem_top.sv:140`). Bind it on every master **and** slave port
  of the interconnect.
- Bind `axi_random_stall.sv` on slave ports (currently unused anywhere).
- Directed: access to each hole → DECERR → correct access-fault cause; D and I miss
  in the same cycle → both complete; uncached UART read issues exactly one AXI read.
