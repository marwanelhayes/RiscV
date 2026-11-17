# Zicntr (`cycle`, `time`, `instret`), counter enables, and Sstc

Spec: Unpriv "Zicntr"
([zicntr.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zicntr.adoc));
Priv `mcounteren`, `scounteren`, `mcountinhibit`, `mtime`, `menvcfg`
([machine.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc));
Sstc `stimecmp` ([supervisor.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/supervisor.adoc),
[sstc.adoc](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/sstc.adoc)).
Hardware: [modules/CLINT.md](modules/CLINT.md). Plan blocks B3.3, B7.3, B7.4.
Back to [index](README.md).

## 1. Required by Linux

- `time` is the kernel's clocksource (the `riscv,timer` / SBI timer driver reads it
  with `rdtime`). It may be implemented in hardware or emulated: OpenSBI says "The
  TIME CSR is optional. If TIME CSR is not implemented in hardware then a 64-bit
  MMIO counter is required to track time and emulate TIME CSR"
  ([platform_requirements.md](https://github.com/riscv-software-src/opensbi/blob/master/docs/platform_requirements.md));
  emulation happens in the illegal-instruction handler
  ([sbi_emulate_csr.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_emulate_csr.c),
  `case CSR_TIME`). Emulation costs a full M-mode trap per `rdtime` — very slow in
  simulation, so implement `time` in hardware.
- Timer interrupts to S-mode: either OpenSBI injects them (`mip.STIP` written by M
  on each `mtimecmp` interrupt — needs a writable STIP), or the hart implements
  **Sstc** and the kernel programs `stimecmp` directly.

## 2. CSRs

| CSR | Addr | Width | Notes |
|---|---|---|---|
| `cycle` / `cycleh` | `0xC00` / `0xC80` | 64 total | read-only shadow of `mcycle` |
| `time` / `timeh` | `0xC01` / `0xC81` | 64 total | read-only shadow of memory-mapped `mtime` ("The time CSR is a read-only shadow of the memory-mapped mtime register") |
| `instret` / `instreth` | `0xC02` / `0xC82` | 64 total | shadow of `minstret` |
| `mcounteren` | `0x306` | 32 | bit 0 CY, 1 TM, 2 IR, 3–31 HPMn: if clear, the counter is illegal in S/U. Also gates S-mode `stimecmp` (TM) |
| `scounteren` | `0x106` | 32 | same bits, gates U-mode (only if `mcounteren` also allows) |
| `mcountinhibit` | `0x320` | 32 | optional; "If not implemented, the implementation behaves as though the register were set to zero" |
| `menvcfg` / `menvcfgh` | `0x30A` / `0x31A` | 64 total | **mandatory** with U-mode ("In harts with U-mode, menvcfg must be implemented"); bit 63 STCE enables Sstc |
| `stimecmp` / `stimecmph` | `0x14D` / `0x15D` | 64 total | Sstc; `STIP = (time ≥ stimecmp)` while `STCE = 1`, and `mip.STIP` becomes read-only |

Rule for RV32 reads of 64-bit counters: software reads `xh`, `x`, `xh` again and
retries on mismatch (OpenSBI does exactly this with `rdtimeh/rdtime/rdtimeh` in
[sbi_timer.c](https://github.com/riscv-software-src/opensbi/blob/master/lib/sbi/sbi_timer.c)).
Hardware need not latch.

`mtime` must "increment at constant frequency" and the platform must expose that
frequency; Linux reads it from the DT `timebase-frequency` property.

## 3. What exists today

| Item | Status | Evidence |
|---|---|---|
| 64-bit `mcycle`, `minstret`; `cycle`/`instret` (+`h` on RV32) | present | `Design/csr_file.sv:77-78,158-176,276-282` |
| "write replaces that cycle's increment" | present | `Design/csr_file.sv:276-282` |
| `mhpmcounter3–31`, `mhpmevent3–31` read 0 | present | `Design/csr_file.sv:177-182` |
| `time` / `timeh` | **missing** → illegal | `Design/shared_pkg.sv:126-155` (no `0xC01`) |
| `mcounteren`, `scounteren`, `menvcfg`, `mcountinhibit` | **missing** | same |
| `mtime` source | **missing** — the timer interrupt is a raw input pin | `Design/riscv_processor.sv:42-44` |
| Sstc | missing | — |
| ISS | cycle reads taken from the DUT (not predicted) | `Verification/Risc/riscv_iss_pkg.sv:186-187` |

## 4. What must change

| # | Change | Where |
|---|---|---|
| 1 | Input `MTime[63:0]` from the CLINT; `time`/`timeh` read it (`timeh` RV32 only) | `Design/csr_file.sv`, `Design/riscv_processor.sv` |
| 2 | `mcounteren` (CY/TM/IR writable, HPM bits may be read-only 0), `scounteren`; gating: access from S needs `mcounteren.x`, from U needs both | `Design/csr_file.sv` |
| 3 | `menvcfg`/`menvcfgh` (FIOM, CBIE… read-only 0; STCE writable if Sstc) | `Design/csr_file.sv` |
| 4 | Without Sstc: `mip.STIP` writable by M (OpenSBI injects the S timer) | `Design/csr_file.sv:132-135` |
| 5 | Sstc (recommended): `stimecmp` 64-bit, compare against `MTime` every cycle, `STIP` read-only when `STCE = 1`; S access illegal when `STCE = 0` or `mcounteren.TM = 0` | `Design/csr_file.sv` |
| 6 | Optional: `mcountinhibit` (not needed; omit = behaves as 0) | — |

Recommendation: Sstc. Without it each kernel timer tick is S→M `ecall` (set timer) +
M timer interrupt + M→S injection; with it the kernel writes `stimecmp` directly.
PLAN_B B7.4 reaches the same conclusion. The DT must then list `"sstc"` in
`riscv,isa-extensions` — and must **not** if it is absent (a DT that over-claims is
a silent hang).

## 5. Verification hooks

- Directed: `rdtime` from U with `mcounteren.TM=1, scounteren.TM=1` succeeds; with
  either clear → illegal (and OpenSBI-emulated in the full SoC).
- RV32 `timeh` rollover between the two reads.
- ISS: `time` is non-deterministic relative to commits; take it from the DUT like
  `mcycle` today, but **check monotonicity** in the checker (a backwards `time` is a
  real bug that the "use DUT value" approach would hide).
- Sstc: `stimecmp ≤ time` raises STIP within one cycle; writing a larger value
  clears it (spec text in supervisor.adoc §"Supervisor Timer Register").
