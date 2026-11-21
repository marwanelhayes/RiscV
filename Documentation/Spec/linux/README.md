# Linux on the RiscV 5-stage core: specification set

Audited against the RTL at commit `3dfeb41` ("Added 64 bit support and fixed CSR
and FPU valid issues", 2026-11-02) on 2026-11-05. Read-only audit: nothing under
`Design/` or `Verification/` was changed.

This folder is the **specification** layer for the Linux work. The plan of record
(order of work, approval gates, block IDs B0–B9) stays in
[`../../Notes/PLAN_B_LINUX.md`](../../Notes/PLAN_B_LINUX.md), and the change log of what was already
fixed stays in [`../../Notes/DESIGN_VERIFICATION_CHANGES.md`](../../Notes/DESIGN_VERIFICATION_CHANGES.md).
These files do not repeat the plan. They say, per ISA feature and per new hardware
block, *what the specification requires*, *what the RTL does today* (with
`file:line`), and *what has to change*. Block IDs (B2.1, B5.2, …) point back to the
plan.

## Contents

### ISA extensions and privileged features

| File | Covers | Linux needs it? |
|---|---|---|
| [ISA_RV_BASE.md](ISA_RV_BASE.md) | RV32I / RV64I base, FENCE, the old "dialect" | Required |
| [ISA_M.md](ISA_M.md) | M (multiply/divide) | Required (kernel is built `rv32ima`/`rv64ima`) |
| [ISA_A.md](ISA_A.md) | A = Zalrsc (LR/SC) + Zaamo (AMOs) | Required |
| [ISA_F_D.md](ISA_F_D.md) | F, D, `fcsr`, `mstatus.FS` | Optional (`CONFIG_FPU=n`); F alone is useless to Linux |
| [ISA_C.md](ISA_C.md) | C (compressed) | Optional, but `CONFIG_RISCV_ISA_C=y` is the default |
| [ISA_ZICSR.md](ISA_ZICSR.md) | Zicsr CSR instructions and access rules | Required |
| [ISA_ZIFENCEI.md](ISA_ZIFENCEI.md) | FENCE.I | Required |
| [ISA_ZICNTR_TIME.md](ISA_ZICNTR_TIME.md) | Zicntr (`cycle`/`time`/`instret`), counter enables, Sstc | `time` required (HW or emulated) |
| [PRIV_ARCH.md](PRIV_ARCH.md) | M/S/U modes, `mstatus`/`sstatus`, delegation, xRET, WFI, SFENCE.VMA, interrupts | Required |
| [MMU_SV32_SV39.md](MMU_SV32_SV39.md) | `satp`, Sv32 (RV32) and Sv39 (RV64) translation | Required for MMU Linux |
| [PMP.md](PMP.md) | Physical Memory Protection | Optional for OpenSBI, strongly recommended |

### New hardware modules

| File | Module(s) | Plan block |
|---|---|---|
| [modules/TRAP_COMMIT_UNIT.md](modules/TRAP_COMMIT_UNIT.md) | Precise exceptions at M, privilege/delegation logic in `csr_file` | B3.2, B4.1, B4.2, B5.0 |
| [modules/TLB.md](modules/TLB.md) | `tlb.sv` (I-TLB, D-TLB) | B5.1, B5.3 |
| [modules/PTW.md](modules/PTW.md) | `ptw.sv` (page-table walker) | B5.2 |
| [modules/AMO_UNIT.md](modules/AMO_UNIT.md) | `amo_unit.sv` + reservation register + D-cache RMW | B2.1 |
| [modules/CACHE_MAINTENANCE.md](modules/CACHE_MAINTENANCE.md) | D-cache flush / I-cache invalidate FSM, uncached path, bus-error reporting | B2.0, B7.2 |
| [modules/PMP_CHECKER.md](modules/PMP_CHECKER.md) | `pmp.sv` | B6.1 |
| [modules/AXI_INTERCONNECT_MEMORY_MAP.md](modules/AXI_INTERCONNECT_MEMORY_MAP.md) | `axi_interconnect.sv`, `pma.sv`, address map | B7.1, B7.2 |
| [modules/CLINT.md](modules/CLINT.md) | `clint.sv` (`msip`, `mtimecmp`, `mtime`) | B7.3, B7.4 |
| [modules/PLIC.md](modules/PLIC.md) | `plic.sv` | B7.6 |
| [modules/UART_16550.md](modules/UART_16550.md) | `uart_16550.sv` | B7.5 |
| [modules/BOOT_ROM_SOC_TOP.md](modules/BOOT_ROM_SOC_TOP.md) | Boot ROM, `riscv_soc.sv`, unified RAM model | B7.7 |
| [modules/SW_DEVICETREE_OPENSBI_LINUX.md](modules/SW_DEVICETREE_OPENSBI_LINUX.md) | Device tree, OpenSBI build, kernel config, sim-side requirements | B8.x |

Verification architecture and the industry comparison are in
[`../../Notes/verification/`](../../Notes/verification/).

---

## 1. What changed since PLAN_B was written

PLAN_B §1.2/§1.3 and Appendix A were written on 2026-10-21/22 against commit
`9e1d1ba`. Commit `3dfeb41` contains the Phase 1 work. The plan's audit tables are
now **stale**; use the table in §2 below instead.

| Plan item | Plan said | RTL at `3dfeb41` | Evidence |
|---|---|---|---|
| D1 branch/JAL dialect | `PC+4+(imm<<2)` | **Fixed**: standard B/J immediates, `PCBranchD = PCD + SignImmD` | `Design/decode_stage.sv:363-376` |
| D2 JALR ignores rs1 | yes | **Fixed**: target `(rs1+imm) & ~1` in EX | `Design/execute_stage.sv:410` |
| D23 LUI/AUIPC/shift-imm/FENCE missing | yes | **Fixed** | `Design/opcode_decoder.sv:141-180`, `Design/alu_decoder.sv` (I-type `3'b001/3'b101`) |
| D22 sub-word loads/stores | ignored `funct3` | **Fixed**: byte enables + extension | `Design/memory_stage.sv:135-171` |
| D3 miss stalls only F/D | yes | **Fixed**: any miss freezes F..W | `Design/hazard_unit.sv:97,160-168` |
| D5 WB-before-MEM forwarding | yes | **Fixed**: MEM first | `Design/hazard_unit.sv:105-112` |
| D8/D15/D16 imprecise traps, MRET never returns, IRQ on bubbles | yes | **Fixed** for every exception the core can raise today (all detected in EX) | `Design/csr_file.sv:221-252` |
| D9/D10 CSR array, wrong `misa` | yes | **Fixed**: explicit registers; `misa = MXL\|I\|M\|F` | `Design/csr_file.sv:58-63,139-184` |
| D11 implicit nets | yes | **Partly**: nets declared, but no file has `` `default_nettype none`` | `grep default_nettype Design/*.sv` → no match |
| D12 `bind` in RTL | yes | **Fixed** | no `bind`/`` `define VERIF`` in `Design/` |
| A1–A8, A10–A12 (RV64) | broken | **RTL done**: `+define+XLEN=64` builds RV64I+M (`OP-32`, `OP-IMM-32`, `LD/SD/LWU`, 6-bit shamt, MXL=2, 64-bit counters, PC[2] instruction select) | `Design/shared_pkg.sv:15-18,33-34,364`; `Design/fetch_stage.sv:95-110`; `Design/execute_stage.sv:364-394` |
| RV64 regression | — | **Not evidenced.** `Scripts/compile.do` passes no `XLEN` define; DESIGN_VERIFICATION_CHANGES §7 still lists "XLEN = 64 regression of every top" as to-do. I could not run Questa in this audit. | `Scripts/compile.do` |
| B0.4/B3.6 "riscv-arch-test via RISCOF" | planned | **Plan is out of date**: riscv-arch-test now says its ACT4 framework *replaces the deprecated riscof tool* | [riscv-arch-test README](https://github.com/riscv-non-isa/riscv-arch-test) |
| B8.4 "`rv32_defconfig`" | planned | Still exists, but mainline `ARCH_RV32I` now `depends on NONPORTABLE` (the 32-bit config fragment sets `CONFIG_NONPORTABLE=y`) | [arch/riscv/Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig), [32-bit.config](https://github.com/torvalds/linux/blob/master/arch/riscv/configs/32-bit.config) |

Takeaway: the "dialect" problem the original task mentions is gone. The core now
decodes a standard RV32IM(F-subset)/RV64IM with Zicsr and M-mode. Everything Linux
needs *beyond* that is still missing.

---

## 2. Gap summary (Linux = OpenSBI + S-mode kernel with MMU)

Legend: **present** = implemented per spec; **partial** = exists but incomplete for
Linux; **missing** = nothing in RTL.

### 2.1 ISA

| Requirement | Status | Evidence | Spec file |
|---|---|---|---|
| RV32I / RV64I base, standard encodings | present | `Design/opcode_decoder.sv:71-203` | [ISA_RV_BASE](ISA_RV_BASE.md) |
| FENCE | present (NOP) | `Design/opcode_decoder.sv:177-180` | [ISA_RV_BASE](ISA_RV_BASE.md) |
| M | present (single-cycle, combinational) | `Design/alu_decoder.sv` funct7 `0000001`; `Design/risc_alu.sv:70-81` | [ISA_M](ISA_M.md) |
| A (LR/SC, AMO*) | **missing** | opcode `0101111` not in `opcode_t` (`Design/shared_pkg.sv:21-37`) → illegal | [ISA_A](ISA_A.md) |
| Zicsr | present (M-mode CSR set) | `Design/csr_file.sv:186-219` | [ISA_ZICSR](ISA_ZICSR.md) |
| Zifencei (FENCE.I) | Implemented on RV32 and RV64 | `Design/memory_stage.sv`, `Design/cache.sv` | [ISA_ZIFENCEI](ISA_ZIFENCEI.md) |
| Zicntr `cycle`/`instret` (+`h`) | present | `Design/csr_file.sv:158-176,276-282` | [ISA_ZICNTR_TIME](ISA_ZICNTR_TIME.md) |
| Zicntr `time`/`timeh` | **missing** (CSR `0xC01` traps; OpenSBI can emulate only if an MMIO timer exists) | `Design/csr_file.sv:177-182` | [ISA_ZICNTR_TIME](ISA_ZICNTR_TIME.md) |
| F | partial (no FLW/FSW, no FMADD family, no `fflags` accrual, FS hardwired Dirty) | `Design/fpu_decoder.sv:13-19`; `Design/csr_file.sv:124,301-303` | [ISA_F_D](ISA_F_D.md) |
| D | missing (FPU fixed to `SINGLE`) | `Design/execute_stage.sv:174`; `Design/shared_pkg.sv:366` | [ISA_F_D](ISA_F_D.md) |
| C | missing | fetch assumes 4-byte instructions (`Design/fetch_stage.sv:112-117`) | [ISA_C](ISA_C.md) |

### 2.2 Privileged architecture

| Requirement | Status | Evidence | Spec file |
|---|---|---|---|
| M-mode trap entry/exit, `mtvec` direct+vectored | present | `Design/csr_file.sv:239-297` | [PRIV_ARCH](PRIV_ARCH.md) |
| Precise exceptions | present **only because every fault is detected in EX**; MMU/PMP/bus faults need commit at M | `Design/execute_stage.sv:412-459` | [TRAP_COMMIT_UNIT](modules/TRAP_COMMIT_UNIT.md) |
| Privilege-mode register (M/S/U) | **missing** (`MPP` hardwired `11`) | `Design/csr_file.sv:123` | [PRIV_ARCH](PRIV_ARCH.md) |
| S-mode CSRs (`sstatus` … `satp`) | **missing** | `Design/shared_pkg.sv:126-155` | [PRIV_ARCH](PRIV_ARCH.md) |
| `medeleg`/`mideleg` | partial (read-only zero) | `Design/csr_file.sv:149-150` | [PRIV_ARCH](PRIV_ARCH.md) |
| ECALL cause by mode (8/9/11) | partial (always 11) | `Design/execute_stage.sv:435-438` | [PRIV_ARCH](PRIV_ARCH.md) |
| SRET, SFENCE.VMA | **missing** (decoded illegal) | `Design/decode_stage.sv:400-419` | [PRIV_ARCH](PRIV_ARCH.md) |
| WFI | partial (legal NOP; allowed by spec) | `Design/decode_stage.sv:416` | [PRIV_ARCH](PRIV_ARCH.md) |
| `mstatus` MPRV/SUM/MXR/TVM/TW/TSR | **missing** | `Design/csr_file.sv:118-126` | [PRIV_ARCH](PRIV_ARCH.md) |
| `mcounteren`/`scounteren`/`menvcfg` | **missing** | not in `csr_index_t` | [ISA_ZICNTR_TIME](ISA_ZICNTR_TIME.md) |
| S-level interrupts (SSIP/STIP/SEIP) | **missing** | `Design/csr_file.sv:127-135` | [PRIV_ARCH](PRIV_ARCH.md) |
| `satp` + Sv32 (RV32) / Sv39 (RV64) | **missing** | — | [MMU_SV32_SV39](MMU_SV32_SV39.md) |
| PMP | **missing** (`0x3A0` is in the generator's *unknown* list) | `Program/riscv_testcase_generator.py:46` | [PMP](PMP.md) |
| Access faults from the bus | **missing**: a non-OKAY refill leaves the line invalid and the cache re-requests forever; nothing reaches the pipeline | `Design/cache.sv:600-630` | [CACHE_MAINTENANCE](modules/CACHE_MAINTENANCE.md) |

### 2.3 Platform / SoC

| Requirement | Status | Evidence | Spec file |
|---|---|---|---|
| Unified physical memory (code and data in one RAM) | **missing**: separate I and D memories, 4 KiB each | `Design/shared_pkg.sv:365`; `Verification/Risc/risc_top.sv` instantiates `InstrMem` and `DataMem` | [AXI_INTERCONNECT_MEMORY_MAP](modules/AXI_INTERCONNECT_MEMORY_MAP.md) |
| Physical address width ≥ 32 bits | **missing** (`FINAL_ADDR_WIDTH = 12`) | `Design/shared_pkg.sv:365` | same |
| Interconnect + address decode + uncached MMIO | **missing** | two private masters (`Design/riscv_processor.sv:46-114`) | same |
| CLINT (`mtime`, `mtimecmp`, `msip`) | **missing** (raw interrupt pins) | `Design/riscv_processor.sv:42-44` | [CLINT](modules/CLINT.md) |
| PLIC | **missing** | — | [PLIC](modules/PLIC.md) |
| 16550 UART | **missing** | — | [UART_16550](modules/UART_16550.md) |
| Boot ROM, reset vector ≠ 0 | **missing** (reset PC = 0) | `Design/wb_stage.sv:70-73` | [BOOT_ROM_SOC_TOP](modules/BOOT_ROM_SOC_TOP.md) |
| Device tree, OpenSBI, kernel image | **missing** | — | [SW_DEVICETREE_OPENSBI_LINUX](modules/SW_DEVICETREE_OPENSBI_LINUX.md) |

---

## 3. The minimum Linux contract, from primary sources

1. **Kernel ISA.** The kernel Makefile builds `rv32ima` / `rv64ima`, appends `fd`
   only with `CONFIG_FPU`, `c` only with `CONFIG_RISCV_ISA_C`, and appends
   `_zicsr_zifencei` with current toolchains
   ([arch/riscv/Makefile](https://github.com/torvalds/linux/blob/master/arch/riscv/Makefile),
   lines 61–75 at the time of reading). So **I, M, A, Zicsr, Zifencei** are the floor.
2. **Firmware.** OpenSBI requires at least `rv32ima_zicsr`/`rv64ima_zicsr`, at least
   one hart with S-mode, direct-mode `mtvec`; PMP and the `time` CSR are optional
   (but without `time` a 64-bit MMIO counter is required)
   ([OpenSBI platform requirements](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md)).
3. **Boot state.** `a0` = hartid, `a1` = DTB address, `satp = 0`, kernel 4 MiB aligned
   on RV32 / 2 MiB on RV64, firmware memory marked reserved in the DT
   ([Linux boot.rst](https://docs.kernel.org/arch/riscv/boot.html)).
4. **RV32 is non-portable in mainline.** `ARCH_RV32I` `depends on NONPORTABLE`
   ([Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig)).
   Default is RV64I. That is a real argument for targeting RV64/Sv39 earlier than
   PLAN_B's B9.5, now that the RV64 datapath exists.
5. **FPU.** "This kernel does not support systems with F but not D" — with F only,
   the kernel clears the F hwcap
   ([cpufeature.c](https://github.com/torvalds/linux/blob/master/arch/riscv/kernel/cpufeature.c)).
   The current single-precision FPU is therefore invisible to Linux.

## 4. Top gaps by blocking order

1. **Unified memory + ≥32-bit physical address + interconnect** — without it no
   firmware image can even be loaded (code and data must share RAM; 4 KiB is ~1000×
   too small).
2. **Privilege modes + S-mode CSRs + delegation + SRET** — OpenSBI skips all trap
   delegation if `misa.S = 0` (`delegate_traps()` in
   [lib/sbi/sbi_trap.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_trap.c)).
3. **A extension** — the kernel is compiled with `a`; the first spinlock or atomic is
   an illegal instruction.
4. **Commit point at M + access/page-fault reporting** — prerequisite for any MMU,
   PMP or bus fault being precise.
5. **Sv32/Sv39 MMU (TLB + PTW + SFENCE.VMA + MPRV/SUM/MXR)**.
6. **CLINT + `time`** (and preferably Sstc), **UART**, **boot ROM**, **FENCE.I**.

## 5. Conventions used in these files

- "Unpriv" = *The RISC-V Instruction Set Manual, Volume I*; "Priv" = *Volume II*.
  Ratified editions: 20240411 per the
  [RISC-V ratified specifications page](https://riscv.org/specifications/ratified/);
  newer editions are on [docs.riscv.org](https://docs.riscv.org/reference/isa/).
  Section text was checked against the AsciiDoc sources in
  [riscv/riscv-isa-manual](https://github.com/riscv/riscv-isa-manual/tree/main/src)
  (`src/priv/*.adoc`, `src/unpriv/*.adoc`) on 2026-11-05.
- RTL references are `path:line` at commit `3dfeb41`.
- Where something could not be verified, the text says so.
