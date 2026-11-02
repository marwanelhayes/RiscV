# Design Changes and Their Verification Counterparts

Status: 2026-10-23 (D32/D33 fixed). Baseline: commit `9e1d1ba` (HEAD, 2026-06-10). Everything
below is uncommitted work in the tree.

Two batches of design changes are covered:

- **2026-10-20** — fixes approved by the owner (x0 guard, CSR, FPU subnormals,
  cache LRU).
- **2026-10-22** — PLAN_B Phase 1 (`docs/PLAN_B_LINUX.md` §1.3, blocks
  B1.1–B1.8): the design is made correct for what the core claims and
  parameterised for XLEN = 32/64.

The verification side was brought in line on 2026-10-22 (Fetch, Decode,
Execute, CSR, FPU, ISS) and 2026-10-23 (Hazard, Memory, WriteBack, risc_top,
FPU references).

Each row says **what the design does now**, **what it did before**, and **which
verification component checks the new behaviour**. "Spec model" means the
checker was written from the ISA / PLAN_B contract, not copied from the RTL.
"Mutation" means the old behaviour was re-introduced in a scratch copy and the
checker failed.

---

## 1. Regression status (32-bit)

| Top | Coverage | Errors | Note |
|---|---:|---:|---|
| csr_top | 100.00% | 0 | |
| hazard_top | 100.00% | 0 | |
| mem_top | 100.00% | 0 | |
| writeback_top | 100.00% | 0 | |
| execute_top | 99.37% | 0 | **D32** fixed 2026-10-23 |
| decode_top | 94.84% | 0 | FPUControlE 20/21, EcallE 1/2 |
| flp_top | 91.17% | 0 | **D33** fixed 2026-10-23 |
| fetch_top | 100.00% | 0 | TB wiring fixed 2026-10-23, see §5 |
| risc_top | — | 0 | ISS lock-step, 10 program seeds with traps and random interrupts |

---

## 2. Cross-cutting design choices

| # | Design change | Before | Verification counterpart |
|---|---|---|---|
| X1 | **XLEN parameter**: `` `XLEN `` (32 default, `+define+XLEN=64`) drives `FINAL_DATA_WIDTH`; `INSTR_WIDTH = 32` fixed; `FINAL_ADDR_WIDTH = 12` (4 KiB per memory) (`shared_pkg.sv`) | 32-bit only, `ADDR_WIDTH = 10` | Every interface/item/predictor width now derives from `FINAL_DATA_WIDTH`. **Gap:** only XLEN = 32 has been regressed; the XLEN = 64 run is still to do. |
| X2 | **PC is XLEN wide** in every stage (`PCF`, `PCPlus4*`, `PCBranchE`, `PCTargetE`, `CsrOutPC`); caches/AXI see `PC[ADDR_WIDTH-1:0]` (D31) | PC = `ADDR_WIDTH` bits (wrapped at 1 KiB) | Fetch, decode, execute, mem, writeback interfaces and items widened; `memory_wr`/`wb_wr` widened. |
| X3 | **Valid bits ride the pipeline**: `ValidD/E/M/W` | No valid bit; a bubble looked like an instruction | Every stage item carries `Valid*`; predictors only expect side effects for valid instructions; `commit_checker` steps the ISS only on `ValidE && !StallE`. |
| X4 | **Only `hazard_unit` drives stalls/flushes**: `StallF/D/E/M/W`, `FlushD/E/M` (D3, D17) | `StallF/StallD/FlushD/FlushE` only; a miss or busy FPU stalled F/D while E/M/W kept moving | Each stand-alone top emulates the same contract: `execute_top` (freeze + FPU wait + trap), `mem_top` (`StallW = !CacheHitM`), `fetch_top`. Hazard predictor written from the contract (§3.4). |
| X5 | **No verification inside RTL**: `` `define VERIF `` and the FPU/CSR `bind`s removed from `execute_stage` (D12) | Bound from inside the design | `bind DUT.FPU flp_wr` / `bind DUT.CSR csr_wr` now in `execute_top.sv`; `bind DUT.Execute.FPU/CSR` in `risc_top.sv`. |
| X6 | **No host paths**: `INSTR_MEM_PATH = "../../Python/binary1.txt"`; instruction memory takes an `INIT_FILE` parameter (D29, V8) | Absolute `/home/...` path, hard-coded `$readmemb` | `riscv_iss_pkg::load_image` and the fetch predictor read the same `INSTR_MEM_PATH`. `Python/binary1.txt` regenerated with the new generator (seed 1). |

---

## 3. Per-block design changes

### 3.1 Fetch (`fetch_stage.sv`, `risc_instruction_memory.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| Bubble = `ADDI x0,x0,0` (`0x00000013`) and `ValidD = 0` on reset/flush | Bubble was `0x00000033` (ADD x0,x0,x0) | Fetch predictor emits `NOP` + `ValidD = 0` on reset/`FlushD`. |
| At XLEN = 64, the 32-bit instruction is selected from the 64-bit I-cache word by `PC[2]`; the ROM packs two instructions per word | n/a | Fetch predictor/ISS index by 32-bit word. **Gap:** XLEN = 64 not run yet. |
| I-cache gets `CPUByteEn = '0` (read-only) | No byte-enable port | `cache_sva` bound in `fetch_top`. |

### 3.2 Decode (`decode_stage.sv`, `risc_control_unit.sv`, `opcode_decoder.sv`, `alu_decoder.sv`, `fpu_decoder.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **Standard B/J immediates** (bit 0 = 0) and `PCBranchD = PCD + imm` (D1) | `PC+4 + (imm<<2)` dialect; B-imm dropped bit 0 | Decode predictor rebuilt from the ISA; ISS checks every next-PC in `risc_top`; generator emits standard encodings (V6). |
| **JALR** decoded (`JalrD`); target `(rs1+imm)&~1` computed in EX (D2) | JALR ignored rs1 | Execute predictor computes the JALR target from the spec; ISS checks next-PC. |
| **LUI, AUIPC** (`UpperD`, `AuipcD`), **SLLI/SRLI/SRAI**, **FENCE** = NOP, **WFI** = legal NOP (D23) | Missing / illegal | Generator emits them; ISS executes them; decode predictor covers U-immediates. |
| **RV64 word ops**: `OP_IMM_32`, `OP_32` (`WordOpD`); illegal at XLEN = 32 | n/a | Execute predictor models `*W` ops from the ISA (`alu(..., word)`). **Gap:** exercised only at XLEN = 64, not yet run. |
| **Full illegal decoding** (D21): reserved funct3/funct7 (R/I, shifts, OP-32), branch funct3 `010/011`, load/store sizes per XLEN, JALR funct3, unknown SYSTEM encodings, FENCE.I, unknown FP encodings, reserved rounding modes `101/110`, writes to read-only CSR space `[11:10]=11` | Opcode-level only | Generator injects illegal encodings; ISS expects illegal-instruction traps (cause 2); `commit_checker` compares trap/cause/`mtval`. |
| **rs1/rs2 read as x0** when the format has no such field (LUI/AUIPC/JAL rs1; non-R/S/B rs2) | Immediate bits treated as register indices → false stalls/forwards | Hazard predictor gets the real `Rs1D/Rs2D`; ISS commit stream would expose a spurious stall-induced mismatch. |
| `MemReadD` added (D4) | Every non-store was a load | Mem env checks loads only when `MemReadM`; `cache` is accessed only for real loads/stores. |
| `ID/EX` register honours `StallE`; carries `ValidE, MemReadE, AuipcE, WordOpE, JalrE` | No `StallE` | Decode interface/item carry the new fields. |
| Integer write-back data is `ResultW` only | `FPUOutW` muxed in at the reg-file on `MoveOperationW == FPUToReg` | Decode/CSR items no longer carry `MoveOperationW` for the integer path. |
| **FEQ/FLT/FLE/FCLASS and FCVT.W[U].S write the integer `rd`** (`MoveOperationD = FPUToReg`) (D20) | Wrote the FPR | Decode predictor written from the ISA; ISS checks the integer write. |
| FPR file: f0 is an ordinary register; width = FLEN | Comment said f0 hard-wired | Covered by hazard FPR forwarding (f0 included) and ISS FPR writes. |

### 3.3 Execute (`execute_stage.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **MEM forwarding uses the M instruction's real result** `ResultM` (ALU / link `PCPlus4M` / CSR read) (D18) | Always `ALUOutM` | Execute predictor's `res_m` from `SelectorM` (spec). |
| **FP→integer results ride `ALUOutM`** (`ResultE`); forward encodings `011/100` removed (D19) | Separate FPU forward sources selected by the *consumer's* `MoveOperationE` | Execute and hazard stimulus constrained to `ForwardA/BE ∈ {0,1,2}`; coverage bins `011/100` deleted (execute, hazard). |
| **CSR write data = forwarded rs1** (`SrcAE`) (D7) | Raw `RD1E` | Execute predictor uses `srca` for CSR writes. |
| **Blocking FPU**: `valid = FPUValidE & ValidE & !FPUDoneE`; the FP instruction holds EX until `done`; `FPUBusyE/FPUDoneE` replace `FPUBusyM/FPUDoneM` (B1.7) | FPU completed out of order into M | `execute_top` emulates the hazard contract; **predictor latches the FP result on the issue cycle** (the FPU latches its operands on accept). This exposed **D32** (§4). |
| **EX/MEM register has `StallM`/`FlushM`**, carries `ValidM`, `MemReadM`, FP flags | Always loaded | Execute predictor: `FlushM` → bubble, `StallM` → hold. |
| **Redirect only on commit**: `PCSrcE = ValidE && !StallE && taken && !TrapTaken` | Redirect regardless of stall (branch could be lost, D17) | Execute predictor `exp.PCSrcE = commit && taken && !trap_taken`; writeback predictor gives redirect priority over `StallF`. |
| **Exception priority and `mtval`** (D24, D25): illegal → misaligned *target* (`mtval` = target) → EBREAK/ECALL → misaligned load/store (`mtval` = address, H/W/D sizes); else 0 | `mtval` = ALU output for every trap; fetch-misaligned tested `PCPlus4E` | Execute predictor's exception block follows the Privileged spec; ISS checks `mepc/mcause/mtval` one cycle after each trap. |
| RV64 word-op operand/result conditioning (sign/zero extension, `shamt[4:0]`) | n/a | Execute predictor `alu(..., word)`. **Gap:** XLEN = 64. |

### 3.4 CSR file (`csr_file.sv`, `csr_defs.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **Explicit registers + `case` read mux; unknown CSR → illegal** (D9, D21) | 4096 × XLEN array, any address readable/writable | CSR predictor/RAL re-rooted to per-register paths; ISS `csr_read` existence check; generator emits `UNKNOWN_CSRS`. |
| **Precise traps in the same cycle** (`TrapTaken`, `TrapIsSet` combinational); every side effect only on `Commit` (D8) | Registered `TrapIsSet`; trap entry re-ran every stalled cycle; trapping instruction + 1 younger committed | CSR env has a `Commit` input; `commit_checker` checks `TrapTakenE` per commit and that the trapping instruction writes nothing. |
| **MRET redirects to `mepc`** (D15) | `HandleReturn` cleared `TrapIsSet` → MRET never jumped | CSR predictor (V9 fixed); ISS next-PC check on MRET; generator's trap handler returns via MRET. |
| **Interrupts only on a valid, committing EX instruction**; priority MEI > MSI > MTI; vectored `mtvec` (D16) | Taken in any cycle (`mepc` = garbage on bubbles) | `risc_test` now drives random interrupt pulses; ISS takes the same interrupt; `mepc/mcause` compared. |
| **`mip` reflects the lines directly** (D26) | Registered copy OR live line → pending one cycle late | CSR predictor from spec. |
| **`misa` = MXL \| I \| M \| F** (`0x4000_1120` / `0x8000_0000_0000_1120`) (D10) | `0x4000_0100` (I only) | CSR predictor / RAL value. |
| **`mstatus.MPP` reads M; `FS` = Dirty with `SD`** (D27) | MPP = 0, FS = Off | CSR predictor. |
| **64-bit `mcycle`/`minstret`** (+`mcycleh/minstreth` on RV32), `cycle/instret` read-only aliases, `marchid/mimpid/mhpm*` read zero, `mstatush` (D28) | 32-bit `mcycle` at 0xC00 only | CSR predictor; cycle-counter reads are masked (`chk_csrout = 0`) because their value depends on stall timing; `minstret` checked. |
| `mhartid`, `medeleg`, `mideleg` read-only zero (approved 2026-10-20) | Writable | CSR predictor / RAL. |
| CSR bit positions moved to `csr_defs.sv` as positions (masks built per XLEN) | 32-bit literal masks | Same positions used by the CSR predictor. |

### 3.5 Hazard unit (`hazard_unit.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **Forwarding priority MEM before WB** (D5) | WB checked first | Hazard predictor `gpr_forward()`: MEM → WB → RF (spec). **Mutation:** WB-first in `risc_top` → 675 ISS errors. |
| **FPR forwarding includes f0** (D6) | f0 skipped | Hazard predictor `fpr_forward()` has no f0 exception. |
| **x0 never a dependency** (load-use and forwarding) | Load-use on x0 possible | Hazard stimulus keeps x0 in the pools (old `NoZeroReg` constraint removed). |
| **Stall rules**: any cache miss freezes F..W; FPU wait holds F/D/E and bubbles M; load-use holds F/D and bubbles E (only if E advances); trap flushes M | Miss/FPU stalled F/D only | Hazard predictor `compute()` from §3.4; new outputs `StallE/M/W`, `FlushM` added to interface/item/compare/coverage; `FPUBusyM` → `FPUDoneE`, `MoveOperationE` removed. |
| Redirect contract: redirects only when EX advances | n/a | Hazard stimulus constraint `RedirectOnlyWhenEAdvances`; coverage `ignore_bins` for the impossible `StallE ∧ ¬StallD` and `FlushM ∧ StallM`. |

### 3.6 Memory stage and caches (`memory_stage.sv`, `cache.sv`, `risc_data_memory.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **Sub-word loads/stores** LB/LH/LW/LBU/LHU (+LWU/LD/SD at XLEN 64): load alignment + sign/zero extension; store lane replication + byte enables (D22) | `funct3M` ignored: everything behaved as LW/SW | Flat mem predictor rewritten from the ISA (byte-exact image, V3 closed); stimulus `OnlyWord` removed, legal sizes per XLEN, naturally aligned addresses; coverage `LoadSize × Lane`, `StoreSize × Lane`. **Mutation:** LB zero-extending → 70,478 mismatches. |
| **D-cache accessed only for real loads/stores** (`CPUReadEn = MemReadM`) (D4) | Every non-store read the cache at `ALUOutM` | Mem stimulus generates non-memory instructions; `ReadDataW` compared only for loads. |
| **`cache.sv` byte enables** (`CPUByteEn`): write hit merges bytes; write miss refills then merges | Full-word writes only | Mem predictor byte merge; `mem_ral_checker` checks each AXI write beat by strobe; `cache_sva` bound in `mem_top`. |
| **True LRU** (age ranks) (approved 2026-10-20) | Saturating counters | `cache_sva` has an independent true-LRU reference (mutation-checked 2026-10-20). |
| **MEM/WB register honours `StallW`**, carries `ValidW` | Always loaded | `mem_top` drives `StallW = !CacheHitM`; predictor advances only when `!StallW`. |
| Memories index words by `$clog2(DATA_WIDTH/8)` | Fixed `[ADDR-1:2]` | Mem predictor uses `BYTE_OFF_W`. **Gap:** `mem_ral_checker` still peeks with `[ADDR-1:2]` (fine at 32, wrong at 64). |

### 3.7 Write-back (`wb_stage.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **PC update priority: trap/MRET > taken branch > sequential (held by `StallF`)** — a branch is never lost to a fetch stall (D17) | `StallF` blocked the branch | Writeback predictor `update_shadow()` from the contract. **Mutation:** `PCSrcE && !StallF` → 1,358 errors (the exact count the old predictor produced, because it encoded the old priority). |
| PC/data ports XLEN wide | `ADDR_WIDTH` PC | Interface/item/`wb_wr` widened. |
| — | — | Predictor clone bug fixed (V4: `$cast(exp_clone, exp)` published the live object — the cause of the old ResultW mismatches). |

### 3.8 FPU (`risc_fpu.sv`, `flp_add_sub.sv`, `flp_mul.sv`, `flp_div.sv`, `flp_sqrt.sv`)

| Design change | Before | Verification counterpart |
|---|---|---|
| **Subnormal inputs/outputs** via a shared `RoundPack` (gradual underflow) in add/sub, mul, div (approved 2026-10-20) | Flush-to-zero | Exact SV reference `flp_ref_pkg` (320-bit exact arithmetic) and Python DPI golden `fpu_golden.py`, both honouring every rounding mode. |
| **FSQRT rewritten** as a restoring digit recurrence, correctly rounded in all modes (states `SQRT_NORM/ITER/ROUND`) | Newton-style multiply/add sequence | Same references; FPU env green for FSQRT. |
| **FCVT.W[U].S / FCVT.S.W[U]** rounded once with guard/sticky, RISC-V saturation (NaN → max) | Truncation / no saturation | References implement RISC-V saturation. |
| **FMIN/FMAX**: −0 < +0; one NaN → other operand; two NaNs → canonical NaN | IEEE-incomplete | References. |
| DYN rounding resolved by the core (`frm`), FPU treats DYN as RNE | — | Execute predictor resolves DYN from the ISS `frm`; FPU references use RNE for DYN. |
| — | — | Reference fix 2026-10-23: exact cancellation `x + (−x)` is an exact zero, **not** an underflow, in both references (only `x − x` was exempt). |

### 3.9 Misc

| Design change | Before | Verification counterpart |
|---|---|---|
| `non_restoring_divider`: overflow test `{1'b1, 0…}` (WIDTH-safe), all-ones quotient as `'1`, `NegativeQuotient` declared (D30, D11) | `1 << (WIDTH-1)` in 32-bit `int` | Execute predictor `mul_div` (via ISS) incl. divide-by-zero and `MIN/−1`. |
| Integer reg file: one XLEN-wide array; **x0 write guard** (approved 2026-10-20) | 4 byte-lane instances, x0 writable | Decode RAL (GPR) + ISS integer-write check. |
| `riscv_processor`: all new nets declared and wired (D11) | Implicit nets | Compiles clean; `risc_top` binds every stage wrapper. |

---

## 4. RTL bugs found by the new checkers (fixed 2026-10-23, owner-approved)

| ID | Where | Defect | Found by | Fix | Proof |
|---|---|---|---|---|---|
| **D32** | `risc_fpu.sv:326`, `execute_stage.sv:178`, `hazard_unit.sv:162` | The FPU had no view of the stage stall: `done`/`Result` cleared the cycle after completion. A cache freeze in the `done` cycle held EX, `valid` (`FPUValidE & ValidE & !FPUDoneE`) rose again, and the FPU re-accepted and re-ran the instruction with that cycle's operands (stale `RD1FE` once the forwarding source had retired). | Execute env: 40 `FPUOutM`/`ALUOutM` mismatches, each ~1 FP latency after a re-accept. | New input `hold` on `risc_fpu` (= `StallE` in `execute_stage`, `1'b0` in `flp_top`); line 326 is now `else if(done_reg && !hold)`. Verification side: `flp_monitor` counts one completion per rising edge of `done` (it stays high while held). | Execute env 40 → 0; probe: 128 done-during-freeze cycles, 0 re-accepts; risc_top 10/10 seeds. |
| **D33** | `flp_add_sub.sv` `AlignWithShiftGRS` | At an exponent difference of exactly `FRAC_BITS+2` (25) the hidden bit belongs in the round bit but the function took the "shift everything out" branch and folded it into sticky. Effective subtraction from a power of two renormalises one bit left (r → g), so the rounding flipped: `0x34690a4c + 0xc0800000` RNE → `0xc0800000`, correct `0xc07fffff`. | FPU env: 1 mismatch in 277k (random stimulus almost never makes the large operand an exact power of two). | In-range branch extended to `sh <= FRAC_BITS+2`, guard bit read only when `sh <= FRAC_BITS+1`. Verification side: `flp_seq` injects binade-edge pairs (power of two ± operand 20–30 binades smaller) in 5% of items. | FPU env 1 → 0; pre-fix RTL now fails the env with 28 mismatches; directed 20k-vector run (all modes) 0 vs 117 on pre-fix. |

---

## 5. Fetch environment wiring issue (was 65%, fixed 2026-10-23 → 100%)

The old `COVERAGE_README` note ("`StallD`/`CacheHitF` partly X") is out of date:
those coverpoints are now 100%. The remaining 35% come from two TB issues, not
from the RTL:

1. **`StallBit` / `FlushBit` are never sampled.** They are *request* signals
   that live only in `fetch_interface` (driven by `drv2intf` from the item's
   `StallD/FlushD`). `fetch_top` turns them into the DUT pins
   (`StallD = StallBit | !CacheHitF`, `FlushD = FlushBit & !StallD`), but
   `intf2mon` never copies them into the monitored item, and the `pck`
   clocking block does not list them. `StallBit_cg`, `FlushBit_cg` and
   `StallBit_x_FlushBit_cx` therefore sample an unset field and stay at 0%.
2. **Two cross bins are unreachable by construction.**
   `FlushD = FlushBit & !StallD` makes `StallD ∧ FlushD` and
   `CacheMiss ∧ FlushD` impossible, so `Stall_x_Flush_cx <hi,hi>` and
   `CacheHit_x_Flush_cx <miss,hi>` can never be hit. This is also what the
   pipeline contract says (a redirect is only raised when EX advances, and any
   miss or stall prevents that), so they should be `ignore_bins` with that
   rationale, not holes.

Also, the interface header claims StallD/FlushD exclusion "is enforced by the
sequence item constraints" — it is actually enforced by the `fetch_top` glue.

**Fix applied (TB only):** `StallBit/FlushBit` added to `pck` and copied in
`intf2mon`; the item fields are now observed (non-`rand`, copied in
`do_copy`/`copy_inputs`); `initialize` resets the requests instead of the
top-driven pins; `fetch_wr` (risc_top, passive) sets request = pin; the two
crosses carry `ignore_bins` with the contract rationale; the interface header
now describes the real mechanism. Result: Fetch 100%, 0 errors; risc_top
unchanged (0 mismatches).

---

## 6. Verification-only changes without a design counterpart

| Change | Why |
|---|---|
| `commit_checker` bound into `risc_top` (ISS lock-step on every EX commit, MEM store, WB write; trap CSRs after each trap) | V2: architectural reference for the whole core |
| `risc_test` ends on `ISS_DONE` (self-loop committed), drains 64 cycles, triggers `ISS_FINAL`; timeout is an error | V7: a run that executes garbage can no longer pass |
| `risc_test` random interrupt pulses (40–200 cycles apart, 1–3 cycles long) | B1.6 exit: random interrupts (0–5 taken per seed) |
| `risc_test` `MEM_DEPTH = 2**(ADDR-2)` (was `2**(ADDR-5)` = 128 words), cycle factor 16 | Program budget was clipped to 128 words |
| Generator rewritten (standard encodings, all base instructions, traps, interrupts, self-loop end) | V6 |
| Predictor clone fixes in execute/writeback | V4 |

## 7. Still to do

- XLEN = 64 regression of every top (B1.1 exit gate).
- Random AXI latency in `risc_top` (`axi_random_stall` exists, not bound) (B1.5 exit gate).
- Decode `FPUControlE` / `EcallE` holes.
- `mem_ral_checker` word index per XLEN.
- `Memory/unused/mem_flat_predictor_pkg.sv` is the compiled predictor; `Memory/mem_predictor_pkg.sv` is dead — move/delete when convenient.
