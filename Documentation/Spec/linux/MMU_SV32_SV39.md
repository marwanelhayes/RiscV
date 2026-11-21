# Virtual memory: `satp`, Sv32 (RV32) and Sv39 (RV64)

Spec: Priv "Supervisor-Level ISA" — `satp`, SFENCE.VMA, Sv32, Sv39, Svade/Svadu
([supervisor.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/supervisor.adoc),
[svadu.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/svadu.adoc)).
Hardware: [modules/TLB.md](modules/TLB.md), [modules/PTW.md](modules/PTW.md).
Plan blocks B5.0–B5.3, B9.5. Back to [index](README.md).

## 1. Required by Linux

`CONFIG_MMU` defaults to `y` ([Kconfig](https://github.com/torvalds/linux/blob/master/arch/riscv/Kconfig)).
RV32 kernels use 2-level page tables (`PGTABLE_LEVELS` default 2 for 32-bit) →
**Sv32**. RV64 kernels default to 5 levels and probe down; Sv39 is the floor
(RVA20S64 mandates Sv39 + Svade + Svbare,
[rva20.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/profiles/rva20.adoc)).
The kernel enters with `satp = 0` and turns the MMU on itself in `setup_vm()`
([boot.rst](https://docs.kernel.org/arch/riscv/boot.html)).

## 2. `satp`

| | RV32 (`satp` `0x180`) | RV64 |
|---|---|---|
| MODE | bit 31: 0 Bare, 1 Sv32 | bits 63:60: 0 Bare, 8 Sv39, 9 Sv48, 10 Sv57 |
| ASID | bits 30:22 (ASIDMAX 9) | bits 59:44 (ASIDMAX 16) |
| PPN | bits 21:0 (root table PA / 4 KiB) | bits 43:0 |

- "The number of ASID bits is UNSPECIFIED and may be zero." ASIDLEN = 0 is the
  simplest legal choice (then the TLB needs no ASID tag and every `satp` write
  flushes it).
- Writing an unsupported MODE: "the entire write has no effect" (no partial update).
- `satp` is active only when the effective mode is S or U. M-mode fetches are never
  translated; M-mode data is translated only via MPRV (see
  [PRIV_ARCH](PRIV_ARCH.md) §5).
- `mstatus.TVM = 1` → `satp` access in S is illegal.

## 3. Sv32 (RV32)

- VA[31:0] = `VPN[1]`[31:22] · `VPN[0]`[21:12] · offset[11:0]; PA is **34 bits**
  (PPN 22 bits).
- PTE (4 bytes): `PPN[1]`[31:20] · `PPN[0]`[19:10] · RSW[9:8] · D7 A6 G5 U4 X3 W2 R1 V0.
- Page tables: 1024 entries × 4 B = one 4 KiB page; two levels; leaf at level 1 =
  4 MiB megapage.

## 4. Sv39 (RV64)

- VA bits 63–39 must equal bit 38, "or else a page-fault exception will occur".
  `VPN[2]`[38:30] · `VPN[1]`[29:21] · `VPN[0]`[20:12] · offset.
- PA 56 bits; PTE 8 bytes: N[63] (Svnapot), PBMT[62:61] (Svpbmt), reserved[60:54],
  `PPN[2]`[53:28] · `PPN[1]`[27:19] · `PPN[0]`[18:10], bits 9:0 as Sv32. Without
  Svnapot/Svpbmt those bits are reserved: non-zero → **page fault**.
- Three levels; leaves at level 2 = 1 GiB, level 1 = 2 MiB.

## 5. Translation algorithm (Priv §"Virtual Address Translation Process", Sv32 text; Sv39 is the same with LEVELS = 3, PTESIZE = 8)

1. `a = satp.ppn × 4096`, `i = LEVELS − 1`.
2. `pte = M[a + va.vpn[i] × PTESIZE]`. If this access violates PMA/PMP → **access
   fault** of the original access type.
3. If `V = 0`, or `R = 0 ∧ W = 1`, or reserved bits set → **page fault**.
4. If `R = 1 ∨ X = 1` → leaf, go to 5. Else `i = i − 1`; if `i < 0` → page fault;
   `a = pte.ppn × 4096`, go to 2.
5. Misaligned superpage: `i > 0` and `pte.ppn[i−1:0] ≠ 0` → page fault.
6. U-bit check against the effective mode, SUM and MXR → page fault on violation.
7. (Shadow-stack rules — not applicable without Zicfiss.)
8. R/W/X check for the access type (fetch needs X; load needs R, or X with MXR;
   store/AMO needs W) → page fault.
9. If `A = 0`, or store and `D = 0`: with **Svade**, page fault; otherwise
   (**Svadu**) update A/D atomically in memory (PMP/PMA-checked store, re-check
   the PTE if it changed).
10. PA = leaf PPN[LEVELS−1:i] · VA.vpn[i−1:0] (for superpages) · offset.

All implicit PTE accesses are PTESIZE wide. Translations may be cached
(TLB) and need not see page-table stores until an SFENCE.VMA.

**Svade vs Svadu**: Svade (fault on A/D) needs no hardware writes from the walker and
is what RVA20S64 mandates; Linux handles the faults by setting A/D in software.
Choose Svade (PLAN_B B5.2 already does).

## 6. Fault causes and `xtval`

| Access | Page fault | Access fault (PMP/PMA/bus, incl. during the walk) |
|---|---|---|
| Fetch | 12 | 1 |
| Load, LR | 13 | 5 |
| Store, SC, AMO | 15 | 7 |

`tval` = faulting **virtual** address (Sstvala). For a 4-byte instruction fetch
that crosses a page (only possible with C), `tval` = the address of the faulting
part.

## 7. SFENCE.VMA

| rs1 | rs2 | Effect |
|---|---|---|
| x0 | x0 | all translations, all ASIDs |
| x0 | ≠x0 | all VAs for ASID in rs2 (except global) |
| ≠x0 | x0 | VA in rs1, all ASIDs |
| ≠x0 | ≠x0 | VA in rs1 for ASID in rs2 |

"It is always legal to over-fence … simpler implementations can ignore the virtual
address in rs1 and the ASID value in rs2 and always perform a global fence." With
small TLBs: always flush everything. SFENCE.VMA must also flush younger instructions
already fetched/translated (serializing).

## 8. What exists today

Nothing: no `satp`, no TLB, no walker, no page-fault causes
(`Design/shared_pkg.sv:126-155,176-191`), no SFENCE.VMA decode
(`Design/decode_stage.sv:398-419`). Physical address is 12 bits
(`Design/shared_pkg.sv:365`), so even the Sv32 34-bit PA (or the 32-bit cap
PLAN_B §2.2 uses) is far away. The cache is physically indexed/tagged and
`CacheHit` drives the stall directly (`Design/cache.sv:60-66`;
`Design/hazard_unit.sv:97`).

## 9. Pipeline integration in *this* core

| Point | Design decision |
|---|---|
| Fetch (F) | I-TLB lookup on `PCF` in parallel with the I-cache index (VIPT is safe while `sets × line_bytes ≤ 4 KiB`; today 32 lines/16-way = 2 sets × 16 B, `Design/shared_pkg.sv:372-374`). Tag compare uses the PA. I-TLB miss → `StallF` request to `hazard_unit`, PTW walk. Fault → carry `ExcValidD = 1, cause 12/1, tval = PCF` with a bubble instruction to M. |
| Data (M) | Address is computed in EX (`AddressE`); D-TLB lookup in M before the D-cache tag compare (or in EX→M register stage). Miss → freeze all stages (same as a D-cache miss today). Fault → exception at M. |
| Commit | Must be at M (page faults are only known there). **Prerequisite: B5.0** — today traps commit in EX (`Design/execute_stage.sv:412-413`), so a younger CSR write or a branch in EX could already have committed when the M load faults. |
| Serialization | `satp` write, SFENCE.VMA, `mstatus` write (MPRV/SUM/MXR), xRET (mode change) → flush F/D/E and refetch. |
| PTW memory port | Through the D-cache CPU port (coherent with kernel page-table stores, no extra master). |
| MPRV | D-side effective mode = `MPRV ? MPP : PrivMode`; I-side ignores MPRV. |

## 10. Verification hooks

- `riscv-tests` `-v-` variants (`rv32ui-v-*`, `rv32ua-v-*`, …) run the user tests
  under a virtual-memory test environment
  ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)).
- CVA6 runs a dedicated Sv32 MMU arch-test list in its regression
  (`verif/regress/dv-riscv-mmu-sv32-test.sh` in
  [openhwgroup/cva6](https://github.com/openhwgroup/cva6/tree/master/verif/regress)).
- [riscv-dv](https://github.com/chipsalliance/riscv-dv) "Page table randomization and
  exception" and an MMU stress suite.
- Directed list that maps 1:1 onto §5: each of steps 2–9 must have a test that hits
  the fault; plus megapage, misaligned megapage, SUM on/off, MXR on/off, MPRV with
  MPP = U/S, TLB hit after PTE change without SFENCE (allowed stale), and with
  SFENCE (must refetch).
