# Software side: device tree, OpenSBI, kernel, rootfs, and simulation requirements

PLAN_B B8.2–B8.5 already contains a complete draft DTS and build commands
([../../../Notes/PLAN_B_LINUX.md](../../../Notes/PLAN_B_LINUX.md) §B8). This file lists only the
**corrections and additions** found while checking those against current upstream
sources. Back to [index](../README.md).

## 1. Corrections to PLAN_B §B8

| PLAN_B says | Upstream today | Action |
|---|---|---|
| `make … PLATFORM_RISCV_ISA=rv32ima_zicsr_zifencei` | OpenSBI's default is `rv$(XLEN)imafdc` (+ `_zicsr_zifencei`) (`Makefile` lines ~320–324 in [OpenSBI](https://github.com/riscv-software-src/opensbi/blob/master/Makefile)) | Keep the override — forgetting it builds firmware with `fd`/`c` instructions that trap illegal on this core |
| Kernel `rv32_defconfig` | Still exists, but `ARCH_RV32I` `depends on NONPORTABLE`; the `32-bit.config` fragment sets `CONFIG_NONPORTABLE=y` ([Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig), [32-bit.config](https://github.com/torvalds/linux/blob/master/arch/riscv/configs/32-bit.config)) | Use `make rv32_defconfig` (it merges the fragment), then trim |
| Buildroot ISA `rv32ima` | Buildroot's RISC-V default is `BR2_riscv_g` (selects F and D) ([arch/Config.in.riscv](https://github.com/buildroot/buildroot/blob/master/arch/Config.in.riscv)) | Select `BR2_riscv_custom` + `BR2_RISCV_ISA_RVM` + `BR2_RISCV_ISA_RVA`, ABI `BR2_RISCV_ABI_ILP32` (no F/D/C) |
| Start from scratch | Buildroot ships `qemu_riscv32_virt_defconfig` (Linux 6.18.7, `rv32` kernel defconfig, OpenSBI 1.6, `PLAT=generic`) | Start from it, change ISA/ABI, switch rootfs to initramfs, then boot on `qemu-system-riscv32 -M virt -cpu rv32,c=off,f=off,d=off` first |
| riscv-arch-test "via RISCOF" | ACT4 framework "replaces the deprecated riscof tool" ([riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test)) | Plan the compliance harness on ACT4 |

## 2. Device tree rules that cause silent hangs

1. **ISA string must equal the RTL.** Use `riscv,isa-base = "rv32i"` and
   `riscv,isa-extensions = "i", "m", "a", "zicsr", "zifencei", "zicntr"` (+ `"sstc"`
   only if implemented, never `"f"`/`"d"` with the current FPU, never `"c"`).
   Binding: [riscv/cpus.yaml](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/riscv/cpus.yaml).
   `misa` must agree (OpenSBI reads `misa` directly, e.g. `misa_extension('S')` gates
   delegation in [sbi_trap.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_trap.c)).
2. **`mmu-type = "riscv,sv32"`** (RV32) / `"riscv,sv39"` (RV64).
3. **`timebase-frequency` = clk / `TIMEBASE_DIV`** of the CLINT.
4. **`/chosen/stdout-path`** pointing at the UART (OpenSBI generic requires it when
   there are several consoles; harmless otherwise —
   [generic.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform/generic.md)).
5. **A timer node is mandatory** for OpenSBI generic ("The FDT must have a DT node
   for timer device") — the CLINT node with `riscv,clint0`.
6. UART without `interrupts` until the PLIC exists (polled 8250).
7. Memory node size = what the RAM model really backs.

## 3. Hardware behaviours OpenSBI probes (each must trap or work, never "read 0 silently")

| OpenSBI action | Hardware requirement | Spec file |
|---|---|---|
| `hart_detect_features()` probes CSRs with `csr_read_allowed()` | unimplemented CSRs **trap illegal** | [ISA_ZICSR](../ISA_ZICSR.md) |
| PMP count/granularity probe on `pmpaddr0` | 0 entries → `pmpaddr0` traps; or full PMP | [PMP](../PMP.md) |
| `delegate_traps()` writes `mideleg`/`medeleg` | writable when `misa.S` | [PRIV_ARCH](../PRIV_ARCH.md) |
| illegal-instruction emulation (`rdtime` etc.) reads `mtval`, else re-fetches with MPRV | MPRV + MXR on loads in M | [PRIV_ARCH](../PRIV_ARCH.md) §5 |
| misaligned load/store emulation (`sbi_trap_ldst.c`) | misaligned trap with `mtval` = address | [ISA_RV_BASE](../ISA_RV_BASE.md) |
| timer injection without Sstc | `mip.STIP` writable in M | [ISA_ZICNTR_TIME](../ISA_ZICNTR_TIME.md) |

## 4. Kernel config deltas from `rv32_defconfig`

`CONFIG_FPU=n`, `CONFIG_RISCV_ISA_C=n`, `CONFIG_RISCV_ISA_V=n`,
`CONFIG_RISCV_ISA_ZICBOM=n`, `CONFIG_SMP=n`, `CONFIG_MODULES=n`,
`CONFIG_SERIAL_8250=y`, `CONFIG_SERIAL_8250_CONSOLE=y`, `CONFIG_SERIAL_OF_PLATFORM=y`,
`CONFIG_HVC_RISCV_SBI=y` (SBI console fallback), initramfs built in
(`CONFIG_INITRAMFS_SOURCE`). Extensions that the kernel only uses "when detected at
boot" (Zba/Zbb/Zicboz/…) are safe to leave enabled — detection uses the DT string.
`CONFIG_RISCV_ISA_C=y` is **not** safe: it changes the compiled code.

## 5. Simulation-side requirements

| Need | Why | Proposal |
|---|---|---|
| Sparse RAM ≥ 32 MiB | kernel + initramfs | SV associative array in the SoC TB ([BOOT_ROM_SOC_TOP](BOOT_ROM_SOC_TOP.md)) |
| Image loader | one `fw_payload.bin` at `0x8000_0000` | `elf2hex.py` (PLAN_B B0.1) or DPI loader |
| Console | pass/fail evidence | `uart.log` from `TxByte` |
| End of test | regression needs an exit code | test finisher at `0x0010_0000` + DT `syscon-poweroff` |
| Speed | a boot to shell is roughly 10⁸ instructions or more (PLAN_B estimates 100M–500M; not measured here) | Verilator build of `riscv_soc` (keep `Design/` free of classes/`bind`); checkpoint after OpenSBI; FPGA optional |
| Reference run | find hangs fast | the same image on QEMU and Spike (`--isa=rv32ima_zicsr_zifencei`) with instruction trace; diff first divergence |

CVA6 runs Linux-class software as a regression item: `verif/regress/linux.sh` runs a
BBL+kernel image on the Verilator testbench with a 40M-cycle timeout and a
post-run address check ([openhwgroup/cva6](https://github.com/openhwgroup/cva6/blob/master/verif/regress/linux.sh)).
That is the model to copy: Linux boot as a *nightly test with a pass criterion*,
not a one-off demo.
