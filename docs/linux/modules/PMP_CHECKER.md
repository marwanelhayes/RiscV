# `pmp.sv` — PMP comparator / checker

Spec basis: [PMP](../PMP.md). Plan block B6.1. Back to [index](../README.md).

## 1. Purpose

Pure combinational check: given a physical address range, access type and
effective privilege, decide allow/deny from the PMP CSR state held in `csr_file`.
Two instances: fetch side (after I-TLB) and data side (after D-TLB, shared with
PTW reads).

## 2. Parameters and ports

```
parameter int ENTRIES    = 16;   // CSR entries (0, 16 or 64 per spec)
parameter int WORKING    = 16;   // entries with real storage; rest read-only zero
parameter int PADDR_W    = 34;   // RV32 Sv32; 56 for RV64
parameter int GRAN_G     = 0;    // granularity 2^(G+2) bytes

input  logic [PADDR_W-1:0]   Addr,         // lowest byte of the access
input  logic [3:0]           SizeBytes,    // 1,2,4,8 (all bytes must match one entry)
input  logic                 IsFetch, IsLoad, IsStore,   // AMO/SC = store
input  priv_mode_t           EffMode,      // MPRV-effective for data, S for PTW
input  logic [7:0]           PmpCfg  [ENTRIES],
input  logic [PADDR_W-3:0]   PmpAddr [ENTRIES],
output logic                 Allow
```

## 3. Algorithm (one `always_comb`, lowest index wins)

```
Allow = (EffMode == M) || (WORKING == 0);       // default when nothing matches
for i = ENTRIES-1 downto 0:                      // reverse loop: lowest index wins
  case A(i): OFF  -> no match
             TOR  -> lo = (i==0) ? 0 : PmpAddr[i-1]<<2 ; hi = PmpAddr[i]<<2
             NA4  -> base = PmpAddr[i]<<2, size 4
             NAPOT-> size from trailing ones of PmpAddr[i]
  any_byte = range ∩ [Addr, Addr+SizeBytes) ≠ ∅
  all_bytes = [Addr, Addr+SizeBytes) ⊆ range
  if any_byte:
     if !all_bytes           Allow = 0;           // partial match always fails
     else if (EffMode==M && !L(i)) Allow = 1;
     else Allow = (IsFetch & X(i)) | (IsLoad & R(i)) | (IsStore & W(i));
```

CSR-side rules (in `csr_file`, not here): `R=0,W=1` legalised on write; locked
entry ignores writes to `pmpcfg[i]` and `pmpaddr[i]`, and `pmpaddr[i-1]` if entry
`i` is TOR; NA4 not selectable when `GRAN_G ≥ 1`.

## 4. Integration

| Point | Fault |
|---|---|
| Fetch PA | instruction access fault (1), `tval` = VA (PC) |
| Load / LR PA | load access fault (5), `tval` = VA |
| Store / SC / AMO PA | store/AMO access fault (7), `tval` = VA |
| PTW PTE read (EffMode = S) | access fault of the *original* access type |

Writing any PMP CSR must be followed by `SFENCE.VMA x0, x0` (software rule). If TLB
entries cache PMP results, that SFENCE must also clear them; simplest is to not
cache PMP results in the TLB at all (check every access).

## 5. Verification hooks

- Formal (FPV) is the right tool: assert `Allow == spec_allow(...)` where
  `spec_allow` is an SV function written from the Priv text; the input space (16
  entries × modes × ranges) is far too large to cover by simulation alone, and the
  block has no state. OpenTitan defines a separate FPV sign-off track (V1–V3 for FPV)
  for exactly this kind of block ([development_stages.md](https://github.com/lowRISC/opentitan/blob/master/doc/project_governance/development_stages.md)).
- Coverage: mode × A-field × L × access type × {no/partial/full match} × entry index
  of the winning match.
- System: ACT PMP tests, `rv32mi-p-*`.
