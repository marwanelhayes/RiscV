# `tlb.sv` — I-TLB and D-TLB

Spec basis: [MMU_SV32_SV39](../MMU_SV32_SV39.md). Plan blocks B5.1, B5.3.
Back to [index](../README.md).

## 1. Purpose

Cache leaf translations so fetch and data accesses translate in the same cycle as
the cache lookup. Two instances of one parameterised module: `ITLB` in
`fetch_stage`, `DTLB` in `memory_stage`. Refill comes from the shared
[PTW](PTW.md).

## 2. Parameters

| Parameter | Default | Note |
|---|---|---|
| `DATA_WIDTH` | XLEN | selects Sv32 (32) or Sv39 (64) field widths via `IS_RV64` |
| `ENTRIES` | 8 | fully associative, round-robin (or pseudo-LRU) replacement |
| `ASID_W` | 0 | ASIDLEN = 0 is legal ("may be zero"); then any `satp` write flushes |

## 3. Entry format

| Field | Sv32 | Sv39 |
|---|---|---|
| `Valid` | 1 | 1 |
| `VPN` | 20 | 27 |
| `Level` | 1 bit (0 = 4 KiB, 1 = 4 MiB) | 2 bits (4 KiB / 2 MiB / 1 GiB) |
| `PPN` | 22 | 44 |
| `U G X W R D A` | 7 | 7 |
| `ASID` | `ASID_W` | `ASID_W` |

Store the *leaf PTE permission bits* rather than a pre-computed allow/deny, so a
change of SUM/MXR/mode needs no flush.

## 4. Ports

```
input  logic                  clk, rst,
// lookup (combinational)
input  logic [DATA_WIDTH-1:0] VAddr,
input  logic                  LookupEn,
output logic                  TLBHit,
output logic [PPN_W-1:0]      PPN,          // already merged with VPN bits for superpages
output logic [6:0]            PteFlags,     // U G X W R D A
// refill from PTW
input  logic                  RefillEn,
input  logic [VPN_W-1:0]      RefillVPN,
input  logic [PPN_W-1:0]      RefillPPN,
input  logic [LEVEL_W-1:0]    RefillLevel,
input  logic [6:0]            RefillFlags,
// maintenance
input  logic                  FlushAll      // sfence.vma (any operands), satp write
```

## 5. Permission check (outside the TLB, in the stage that owns the access)

Kept in one shared combinational function `mmu_check()` in `shared_pkg.sv` so the
I- and D-sides cannot drift:

```
fault = (EffMode == U && !U) || (EffMode == S && U && (IsFetch || !SUM))
      || (IsFetch && !X) || (IsLoad && !(R || (MXR && X))) || (IsStore && !W)
      || !A || (IsStore && !D)                     // Svade
```

Fault → page fault 12/13/15 with `tval = VAddr`.

## 6. Pipeline integration

| Side | Where | On miss | On fault |
|---|---|---|---|
| I | `fetch_stage`, parallel with the I-cache index on `PCF`; I-cache tag compare against `{PPN, PCF[11:0]}` | `ITLBMissF` → `hazard_unit` holds F, bubbles D; PTW walks | inject a bubble instruction with `ExcValidD = 1, cause 12` |
| D | `memory_stage`, translate `ALUOutM` before the D-cache tag compare | `DTLBMissM` → freeze all stages (same as a cache miss today, `Design/hazard_unit.sv:97`) | `ExcValidM`, cause 13/15, no cache access |

Timing note: putting TLB lookup + cache tag compare in one cycle is the classic
VIPT arrangement; legal because the cache index bits sit inside the 4 KiB page
offset (`sets × line bytes ≤ 4096`; today `2 × 16 B`). Add an elaboration-time
assertion for this in the TB-side bind, not in `Design/`.

## 7. Verification hooks

- Unit env `Verification/Tlb/` per PLAN_B §3.6 with a reference model that is a
  plain associative array keyed by `{ASID, VPN}` — *not* a copy of the RTL
  replacement policy (compare hit/miss only when the reference is certain, i.e.
  after a flush or within capacity).
- SVA: one-hot (or zero) hit; `FlushAll |=> !TLBHit`; refill entry hits next cycle.
- Coverage: level × permission bits × mode × SUM × MXR × access type.
