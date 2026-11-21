# PMP (Physical Memory Protection)

Spec: Priv "Physical Memory Protection"
([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc)).
Hardware: [modules/PMP_CHECKER.md](modules/PMP_CHECKER.md). Plan block B6.1.
Back to [index](README.md).

## 1. Required?

- OpenSBI: "The PMP CSRs are optional. If PMP CSRs are not implemented then OpenSBI
  cannot protect M-mode firmware and secured memory regions"
  ([platform_requirements.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md)).
- **But** the spec rule "If no PMP entry matches an S-mode or U-mode memory
  operation, the operation fails if at least one PMP entry is implemented and
  succeeds otherwise" means *zero* PMP entries = S/U can access everything, so Linux
  boots without PMP.
- Linux itself never touches PMP; the boot doc only requires that PMP-protected
  memory is marked reserved in the DT ([boot.rst](https://docs.kernel.org/arch/riscv/boot.html)).

Conclusion: PMP is **not on the critical path** to the first shell. It is on the
critical path to a *correct* firmware/kernel split and to passing the privileged
compliance suites. Do it after the MMU, as PLAN_B orders it.

How many entries OpenSBI uses: the root domain is built from up to three firmware
regions (text/data split) plus one all-memory region (`sbi_domain.c`, root domain
setup in [OpenSBI](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_domain.c)),
and FDT drivers may add M-only MMIO regions. 8 entries is a safe floor; 16 is the
common choice. (Exact count per configuration not measured here.)

## 2. Registers

- "Implementations may implement zero, 16, or 64 PMP entries; the
  lowest-numbered PMP entries must be implemented first. All PMP CSR fields are
  WARL and may be read-only zero." So the CSR set is all-or-16-or-64; a design that
  only wants, say, 8 *working* entries implements the 16-entry CSR set and makes
  entries 8–15 read-only zero. `pmpcfg0–15` at `0x3A0–0x3AF`, `pmpaddr0–63` at
  `0x3B0–0x3EF`; PMP CSRs are M-mode only.
- RV32: each `pmpcfgN` holds 4 entries. RV64: only even `pmpcfgN` exist, 8 entries
  each; odd ones are illegal.
- `pmpaddr` = PA[33:2] (RV32) / PA[55:2] (RV64).
- Config byte: `L[7]` · `00[6:5]` · `A[4:3]` · `X[2]` · `W[1]` · `R[0]`.
  A: `0` OFF, `1` TOR, `2` NA4, `3` NAPOT. `R = 0, W = 1` is reserved (WARL).
- Granularity `2^(G+2)` bytes; NA4 not selectable when G ≥ 1. Software discovers G
  by writing all ones to `pmpaddr0` and reading back.

## 3. Matching and checking

| Rule | Text |
|---|---|
| TOR | entry *i* matches `pmpaddr[i−1] ≤ y < pmpaddr[i]`; entry 0 TOR uses 0 as lower bound |
| NAPOT | trailing ones in `pmpaddr` encode size ≥ 8 bytes |
| Priority | "The lowest-numbered PMP entry that matches any byte of a memory operation determines whether that operation succeeds or fails." |
| Partial match | "The matching PMP entry must match all bytes of a memory operation, or the operation fails, irrespective of the L, R, W, and X bits." |
| Permission | L clear and mode = M → succeed; otherwise R/W/X must allow the access type |
| No match | M succeeds; S/U fail if ≥ 1 entry implemented |
| Lock | `L = 1`: entry applies to M too, and writes to its `pmpcfg`/`pmpaddr` are ignored until reset (and `pmpaddr[i−1]` too if entry *i* is TOR) |
| With paging | page-table walks are checked with effective mode S; after changing PMP, M-mode must execute `SFENCE.VMA x0, x0` |
| MPRV | data accesses use the MPRV-effective mode |

Faults: fetch → instruction access fault (1), load/LR → 5, store/SC/AMO → 7,
`tval` = the access's **virtual** address (the original address, not the PA).

## 4. What exists today

Nothing. `0x3A0` is in the generator's list of *unknown* CSRs
(`Program/riscv_testcase_generator.py:46`), i.e. the checker expects it to trap
illegal — correct for "zero entries", which OpenSBI handles (it probes
`pmpaddr0` with `csr_read_allowed()` in
[sbi_hart.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_hart.c)).

## 5. What must change

| # | Change | Where |
|---|---|---|
| 1 | `pmpcfg*`/`pmpaddr*` CSRs (`ENTRIES` parameter, default 16), lock and TOR-lock write rules, WARL R/W legalisation | `Design/csr_file.sv`, `Design/shared_pkg.sv` |
| 2 | Comparator block, one instance on the fetch PA, one on the data/PTW PA | new `Design/pmp.sv` ([PMP_CHECKER](modules/PMP_CHECKER.md)) |
| 3 | Access faults 1/5/7 raised precisely (requires commit at M) | [TRAP_COMMIT_UNIT](modules/TRAP_COMMIT_UNIT.md) |
| 4 | PTW: PMP check on every PTE read (fault = access fault of the original type) | [PTW](modules/PTW.md) |
| 5 | Remove `0x3A0` from `UNKNOWN_CSRS` in the generator; ISS models the entries | `Program/riscv_testcase_generator.py:46`, ISS |

## 6. Verification hooks

- `rv32mi-p-*` PMP-related tests ([riscv-tests](https://github.com/riscv-software-src/riscv-tests)),
  ACT `pmp` tests ([riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test)).
- CVA6 has a dedicated PMP regression (`pmp_cv32a65x_tests.sh`,
  `pmp_lsu_transaction.sh` in
  [cva6/verif/regress](https://github.com/openhwgroup/cva6/tree/master/verif/regress)).
- PMP is a classic formal target: a combinational checker with a crisp spec. A small
  SVA/FPV property set ("access allowed ⇔ spec function") gives exhaustive proof for
  16 entries far faster than simulation.
