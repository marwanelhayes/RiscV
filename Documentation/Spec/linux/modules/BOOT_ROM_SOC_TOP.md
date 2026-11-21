# Boot ROM and `riscv_soc.sv` top

Spec basis: Linux boot requirements ([boot.rst](https://docs.kernel.org/arch/riscv/boot.html)),
OpenSBI firmware entry (`firmware/fw_base.S` in
[OpenSBI](https://github.com/riscv-software-src/opensbi/blob/master/firmware/fw_base.S)),
QEMU `virt` reset vector as the reference implementation
(`riscv_setup_rom_reset_vec()` in [hw/riscv/boot.c](https://github.com/qemu/qemu/blob/master/hw/riscv/boot.c)).
Plan block B7.7. Back to [index](../README.md).

## 1. Purpose

- Put the hart in the state OpenSBI expects and jump to it: `a0 = mhartid`,
  `a1 = DTB address`, PC = `0x8000_0000`. (Linux's own requirement — `a0` hartid,
  `a1` DTB, `satp = 0` — is then satisfied by OpenSBI when it jumps to the kernel.)
- Assemble the SoC: core + interconnect + ROM + CLINT + PLIC + UART + RAM (+ test
  finisher).

## 2. Boot ROM

Mapped at `0x0000_1000`, 4 KiB, read-only (writes → `SLVERR` → store access fault).
Content = the QEMU pattern minus the dynamic-info pointer (not needed with
`FW_PAYLOAD`):

```asm
_reset:                         # 0x1000 = RESET_VECTOR
    csrr  a0, mhartid           # a0 = hart id (0)
    auipc a1, 0                 # a1 = &dtb (DTB placed in ROM after this code)
    addi  a1, a1, (dtb - _reset - 4)
    li    t0, 0x80000000        # lui t0, 0x80000
    jr    t0
    .align 3
dtb:                            # optional: or let FW_PAYLOAD embed the DTB (FW_FDT_PATH)
```

QEMU's version (`auipc t0`, `addi a2`, `csrr a0, mhartid`, load `a1` from a data
word, `jr t0`) is the template; QEMU also passes `a2` = `fw_dynamic_info`, which only
`FW_DYNAMIC` firmware uses. Two options for the DTB:

| Option | Where the DTB lives | Notes |
|---|---|---|
| A | embedded in `fw_payload` via `FW_FDT_PATH` | ROM can then pass any `a1`; OpenSBI's FW_PAYLOAD "allows embedding a flattened device tree in the .rodata section" ([fw_payload.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/firmware/fw_payload.md)) |
| B | in ROM / near top of RAM, address in `a1` | DT can change without rebuilding OpenSBI |

Option A has fewer moving parts for a first boot.

## 3. Core changes needed

| Change | Where |
|---|---|
| `parameter RESET_VECTOR = 32'h0000_1000` (today reset PC = 0) | `Design/wb_stage.sv:70-73`, `Design/riscv_processor.sv` |
| `mhartid` = 0 (already) | `Design/csr_file.sv:163-165` |
| Interrupt inputs renamed/re-sourced from CLINT/PLIC | `Design/riscv_processor.sv:42-44` |
| `MTime[63:0]` input | `Design/riscv_processor.sv` |

## 4. `riscv_soc.sv`

```
module riscv_soc #(
    parameter int DATA_WIDTH   = FINAL_DATA_WIDTH,
    parameter int PADDR_W      = 32,
    parameter int TIMEBASE_DIV = 1
)(
    input  logic       clk, rst,
    output logic [7:0] UartTxByte, output logic UartTxValid,
    input  logic [7:0] UartRxByte, input  logic UartRxValid,
    output logic       SimFinish,  output logic [15:0] SimFinishCode   // test finisher
    // + an AXI port to the external DRAM model, so the TB can provide a sparse RAM
);
```

Instantiates: `riscv_processor Core`, `axi_interconnect Xbar`, `boot_rom Rom`,
`clint Clint`, `plic Plic`, `uart_16550 Uart`, optional `sim_finisher`. DRAM is
**outside** the SoC top (TB-provided) so a sparse associative-array RAM can live in
`Verification/` without polluting `Design/` (PLAN_B B7.7; Unison rule "no sim-only
constructs in `Design/`").

**Test finisher** (strongly recommended for regression): QEMU's `sifive_test`
device ends the run on a write of `0x5555` (pass) / `0x3333` (fail) / `0x7777`
(reset) ([sifive_test.h](https://github.com/qemu/qemu/blob/master/include/hw/misc/sifive_test.h)).
OpenSBI drives such a device through its `syscon-poweroff`/`syscon-reboot` driver
(`fdt_reset_syscon.c`, [OpenSBI](https://github.com/riscv-software-src/opensbi/tree/master/lib/utils/reset)),
so `poweroff` in BusyBox can end the simulation with a pass code. This replaces
"PC left the image" / self-loop detection as the end-of-test signal for system runs.

## 5. Verification hooks

- `Verification/Soc/soc_top.sv`: SoC + sparse RAM + `$readmemh` image load +
  `uart.log` writer + finisher monitor + timeout.
- Bare-metal smoke tests before OpenSBI (PLAN_B B8.1): `hello` over UART, CLINT
  timer interrupt, U→S→M `ecall` chain, page fault handler, AMO spinlock, PMP deny.
- Keep `commit_checker` (or a Spike cosim) on in the SoC TB for the bare-metal tests;
  turn it off (or sample it) for the multi-hundred-million-instruction Linux run.
