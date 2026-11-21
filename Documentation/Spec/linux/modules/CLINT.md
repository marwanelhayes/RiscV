# `clint.sv` — core-local interruptor (`msip`, `mtimecmp`, `mtime`)

Spec: RISC-V ACLINT, which "is defined to be backward compatible with the SiFive
CLINT" ([riscv-aclint.adoc](https://github.com/riscv/riscv-aclint/blob/main/riscv-aclint.adoc));
Priv `mtime`/`mtimecmp` text ([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc)).
Plan blocks B7.3, B7.4. Back to [index](../README.md).

## 1. Purpose

Provide the machine timer (`mtime`, `mtimecmp` → `MTIP`) and the machine software
interrupt (`msip` → `MSIP`), and feed `mtime` to the `time` CSR. Today the three
interrupt causes are raw top-level pins driven by the testbench
(`Design/riscv_processor.sv:42-44`; random pulses in
`Verification/Risc/risc_test_pkg.sv:179-186`).

## 2. Register map (SiFive CLINT layout = ACLINT MSWI at +0x0000 + MTIMER at +0x4000)

| Offset | Width | Name | Access | Reset | Behaviour |
|---|---|---|---|---|---|
| `0x0000` | 32 | `msip` (hart 0) | RW | 0 | bit 0 drives `MSoftIrq`; bits 31:1 read 0 |
| `0x4000` | 64 | `mtimecmp` (hart 0) | RW | unspecified (use all ones so no IRQ at reset) | `MTimerIrq = (mtime >= mtimecmp)`, unsigned |
| `0xBFF8` | 64 | `mtime` | RW | 0 ("On MTIMER device reset, the MTIME register is cleared to zero") | increments every `TIMEBASE_DIV` clocks |

64-bit registers must accept 32-bit accesses to each half (RV32 OpenSBI writes
`mtimecmp` as two 32-bit stores; the safe sequence is write `hi = ~0`, `lo`, `hi`).
Other offsets read 0, writes ignored (or `SLVERR` — pick one and document it; the DT
`reg` size is 64 KiB).

## 3. Ports

AXI4 slave with the same port list as `Design/risc_data_memory.sv` (PLAN_B §3.5),
plus:

```
parameter int TIMEBASE_DIV = 1;          // DT timebase-frequency = clk / TIMEBASE_DIV
output logic        MTimerIrq,
output logic        MSoftIrq,
output logic [63:0] MTime                // to csr_file for time/timeh (and Sstc compare)
```

Keep `TIMEBASE_DIV` a parameter: the DT `timebase-frequency` must equal the real
tick rate, and in simulation a fast tick (small divider) makes the kernel's timer
interrupts arrive in fewer cycles, while too fast a tick makes the kernel spend all
its time in the tick handler. Tune it — it is the one calibration knob of the
Linux-in-sim flow.

## 4. Integration

- `MTime` → `csr_file` (`time`, `timeh`, and `stimecmp` comparison with Sstc).
- `MTimerIrq` → `mip.MTIP`, `MSoftIrq` → `mip.MSIP` (`Design/csr_file.sv:132-135`
  today reads the raw pins).
- Uncached region in `pma.sv`; AMOs not allowed.
- DT: `compatible = "riscv,clint0"` (or `"sifive,clint0"`), `interrupts-extended =
  <&cpu0_intc 3>, <&cpu0_intc 7>`. OpenSBI's timer and IPI drivers match
  `riscv,clint0`/`sifive,clint0` (`fdt_timer_mtimer.c`, `fdt_ipi_mswi.c` in
  [OpenSBI lib/utils](https://github.com/riscv-software-src/opensbi/tree/master/lib/utils)).

## 5. Verification hooks

- `Verification/Clint/` env with a RAL model (it owns architectural registers —
  PLAN_B §3.6 rule). Use the standard RAL built-in sequences
  (`uvm_reg_hw_reset_seq`, `uvm_reg_bit_bash_seq`, `uvm_reg_access_seq`) with a real
  **frontdoor adapter** — this would be the repo's first frontdoor RAL; every
  existing model is backdoor-only (README "no frontdoor adapter").
- SVA: `MTimerIrq == (mtime >= mtimecmp)` every cycle; `mtime` monotonic except on
  writes; half-word write updates only that half.
- System: OpenSBI prints the timer device during boot; `sleep 1` in BusyBox returns.
