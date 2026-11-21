# Speed and Area (PPA) Optimization Report

Date: 2026-11-18. Read-only research: no RTL, verification or script file was changed.
Scope: every module in `Design/` at the current working tree (RV32 default, RV64 checked),
plus design guidance for the planned Linux modules in `Documentation/Spec/linux/modules/`.

How this was produced: six parallel research agents (measurement, front end/control,
integer execute, FPU, cache/memory, future modules + literature), each reading every line
of its modules and synthesizing variants with Yosys. Every headline claim below was then
re-checked against the RTL by the orchestrator (see [§9 Fact-check log](#9-fact-check-log)).

---

## 0. Executive summary

1. **The caches are half the core, and it is a coding-style problem, not a size problem.**
   D-cache + I-cache = 64.6k of 146.8k cells (44% of cells, 52% of NAND2-eq area), 68% of all
   MUX cells, 67% of all flops. Each cache stores only 4 Kbit of data, but the D-cache spends
   ~10 MUX per stored bit because the whole array is copied, patched and re-registered every
   cycle. A recoded cache (one write port, one read port, no reset on data) measured
   **51.6k → 10.4k cells** for the D-cache even when still built from flops.
2. **Fmax is set by serial bit-at-a-time loops in the FPU, then by the single-cycle integer divider.**
   Worst path = **1,054 gate levels** (FPU multiplier normalize + `RoundPack`). With the FPU
   removed: **513 levels** through the combinational divider. For scale, a 32-bit adder is
   ~18 levels. At RV64 the divider becomes the worst path (**1,146 levels**).
3. **The fixes for both are small and mostly proven equivalent.** A log-depth `RoundPack`/normalize
   (SAT-proven for all SP and DP inputs) and an iterative divider (exhaustively checked at 8 bits)
   take the worst path from ~1,054 to ~165 levels (FPU), with the integer side at ~40–50.
4. **Estimated combined result (RV32), summing separately-measured module deltas:**
   ~147k → **~66k cells (−55%)** with flop-based caches, or ~49k cells + 2 SRAM macros;
   worst depth ~1,054 → ~165 levels (≈6× shorter). This sum was not synthesized as one design.
5. **RV64 and the D extension make all of this worse, roughly linearly or quadratically.**
   RV64 core = 1.85× RV32 area; ALU multiplier/divider grow ~3.9×. A D-precision FPU as written
   would be ~138k cells (the size of the whole current core); with the fixes ~55k.

**Status update 2026-11-18:** T1.1, T1.2, T1.3 and T1.5 (+T1.8) are implemented and verified; see [§11](#11-implemented-and-verified-2026-11-18).

---

## 1. Method and caveats

| Item | Value |
|---|---|
| Tool | Yosys (oss-cad-suite) + slang frontend, same flow as `Scripts/synth.sh`, `--keep-hierarchy` for per-module numbers |
| Area unit | Generic gate cells; NAND2-equivalent weights: MUX 2.3, XOR/XNOR 2.3, DFF 4.5, AND/OR/ANDNOT/ORNOT 1.3, NAND/NOR 1.0, NOT 0.7 |
| Speed proxy | `ltp -noff` = longest topological path in generic-gate levels, flop to flop. Good for comparing designs, **not** a timing analysis (no liberty file available) |
| Equivalence | Yosys SAT miters (exhaustive at stated widths) or random-vector simulation; stated per finding |
| Not covered | Real STA, power, FPGA place & route. An earlier Vivado report (March 2026, pre-RV64, pre-AMO, since removed) agreed: 0 BRAM, 0 LUTRAM, 14k FFs |

Important configuration fact: **the core builds direct-mapped caches.** `Design/riscv_processor.sv:30`
sets `CACHE_WAY = 1`. The `CACHE_WAY = 16` in `Design/shared_pkg.sv:390` only reaches the Fetch and
Memory unit benches (`Verification/Fetch/fetch_top.sv:25`, `Verification/Memory/mem_top.sv:30`).
The full core has never been simulated with a set-associative cache.

---

## 2. Measured baseline (RV32)

Total: **146,812 cells, 12,922 DFF, 73,471 MUX, ~311k NAND2-eq**. 0 `$mem` cells inferred anywhere.
(`risc_data_memory` / `risc_instruction_memory` are testbench AXI slaves outside the core.)

| Instance | Cells | DFF | MUX | NAND2-eq | % area |
|---|---:|---:|---:|---:|---:|
| Memory.DCache | 51,524 | 4,402 | 41,387 | 122,265 | **39.3%** |
| Fetch.ICache | 13,047 | 4,252 | 8,316 | 38,828 | **12.5%** |
| FPU.add_sub_unit | 11,935 | 192 | 4,458 | 21,246 | 6.8% |
| FPU.mul_unit (normalize/round) | 10,008 | 170 | 4,639 | ~18.7k | 6.0% |
| ALU.div (combinational) | 10,106 | 0 | 1,303 | 16,193 | 5.2% |
| FPU.div_unit | 8,386 | 282 | 2,851 | 15,183 | 4.9% |
| ALU.mul (wallace_tree) | 9,281 | 0 | 312 | 13,974 | 4.5% |
| FPU booth_multiplier_seq | 7,236 | 151 | 2,174 | 12,406 | 4.0% |
| risc_fpu glue | 5,073 | 120 | 1,040 | ~10.5k | 3.4% |
| Decode.RF (int regfile) | 3,098 | 1,024 | 1,984 | 9,275 | 3.0% |
| Decode.FPRF | 3,093 | 1,024 | 1,984 | 9,269 | 3.0% |
| Execute.CSR | 3,073 | 298 | 803 | 5,821 | 1.9% |
| FPU.sqrt_unit | 2,542 | 172 | 935 | 5,050 | 1.6% |
| Forwarding muxes | 1,356 | 0 | 160 | 1,918 | 0.6% |
| AmoUnit | 1,163 | 0 | 160 | 1,661 | 0.5% |
| Decoders (CU) | 502 | 0 | 11 | 639 | 0.2% |
| WriteBack | 294 | 32 | 96 | 580 | 0.2% |
| Hazard | 129 | 0 | 0 | 216 | 0.07% |

By stage: Memory 40.4%, Execute 39.7% (FPU 25.9%, ALU 10.6%), Fetch 12.6%, Decode 7.0%.

### Logic depth (gate levels)

| Scope | Levels | Path |
|---|---:|---|
| Whole core | **1,054** | `FPU.mul_unit.ExpRes_reg` → normalize loop → `RoundPack` → `result_reg` |
| Core, FPU removed | **513** | `RdW` → forward mux → `ALU.SrcA` → combinational divider → `ALU.Y` → `CSR.Traps` → `Minstret` |
| Core, FPU + divider removed | 115 | same route through `wallace_tree` |
| Core, FPU + div + mul removed | 70 | `Rs2E` → forward mux → `SrcB` → `branch_true` → `CSR.Traps` → `Minstret` |
| flp_add_sub / flp_div | 559 / 551 | `RoundPack` serial loops |
| risc_alu (`branch_true` alone) | 476 | branch decision reads the full result mux, so it waits on the divider |
| memory_stage | 36 | store data → AMO → D-cache `CPUReadData` bypass → load align |
| csr_file / decode_stage | 28 / 28 | |
| DCache / ICache | 20 / 16 | |
| hazard_unit | 8 | |

### RV64 scaling

| Scope | RV32 → RV64 |
|---|---|
| Core area | 311k → 577k NAND2-eq (**1.85×**) |
| DCache | 1.97× (41.7% of core) |
| ALU divider / multiplier | **3.94× / 3.85×** |
| CSR | 1.41× |
| Worst path | 1,146 levels, now the **integer divider** (`Rs2E` → `ALU.RemOutput[63]` → `branch_true` → `CSR.Traps`) |

---

## 3. Ranked roadmap

Ranked by (impact ÷ effort), with correctness risk. "Proven" means a formal or exhaustive check by
the research agent on scratch copies; nothing has been run through the project regressions.

### Tier 1: high impact, small to medium effort (do these first)

| # | Change | Where | Gain (measured on isolated module) | Effort | Risk |
|---|---|---|---|---|---|
| T1.1 | Replace serial normalize loops in `RoundPack` (3 copies) with a log-depth LZC + barrel-shift version (`lzc_wr.sv` already exists) | `flp_add_sub.sv:177,200-218`, `flp_mul.sv:118,141-159`, `flp_div.sv:112,135-153` | adder 11.9k→5.0k cells, 559→132 levels; div 8.3k→4.9k, 552→126 | S | **SAT-proven, all SP and DP inputs** |
| T1.2 | Same for FMUL's 46-step pre-normalize loop | `flp_mul.sv:425-432` | mul depth 616→165 | S | SAT-proven |
| T1.3 | Make the integer divider iterative (2 bits/cycle, 16 cycles), stall via the existing FPU-style busy handshake | `non_restoring_divider.sv:40-58`, `hazard_unit.sv:160-168` | RV32 10.1k→1.35k cells, 462→34 levels; **RV64 39.8k→2.7k, 1,092→41** | M | M: new stall source. 1- and 4-bit/cycle versions exhaustively matched at 8 bits |
| T1.4 | Single shared adder/comparator + one shifter in ALU; take `branch_true` and address directly from the adder, not from the result mux | `risc_alu.sv:93-144` | branch path 476→21 levels; base ALU 1,541→1,065 cells | S | Formally equivalent at 16 bits |
| T1.5 | **Recode cache arrays**: write `data`/`tags` only inside `always_ff` with one byte-masked write port, **no reset on data/tags**, one read port shared by CPU reads and write-back. Keep valid/dirty/LRU as reset flops | `cache.sv:128-133, 186, 276-335, 440-450, 511, 705, 813, 998, 1020` | DCache 51.6k→10.4k (−80%), ICache 13.0k→9.3k; core MUX 73.4k→32.5k. With SRAM macros: DCache 1.8k + SRAM | M (~60 lines) | M: prototype matched original stall cycles and data in a directed Verilator test only; needs mem/fetch/risc regressions + `cache_sva` |
| T1.6 | Replace the Wallace/abs/negate multiplier with one `(W+1)×(W+1)` signed `*` on sign-extended operands | `wallace_tree.sv:84-198` | RV32 9.3k→5.6k cells, 64→40 levels; RV64 35.7k→21.2k | S | Formally equivalent at 8 bits |
| T1.7 | Replace `booth_multiplier_seq` with a registered `*` | `flp_mul.sv:458,561` | 9.5k→5.9k cells; FMUL stalls 11→7 | S | 12k random vectors identical |
| T1.8 | Drop the store-hit `CPUReadData = CPUWriteData` bypass (no consumer; loads are what is checked) | `cache.sv:278-281, 324-327` | memory path 36→24 levels | S | L |

### Tier 2: medium impact or cleanup with low risk

| # | Change | Where | Gain | Effort | Risk |
|---|---|---|---|---|---|
| T2.1 | Remove the async reset loop on both register files (keep `x0` forced to 0 on read; use `initial` zero-fill for sim) | `risc_mem.sv:45-55`, `fp_reg_file.sv:46-56` | Infers `$mem` (LUTRAM on FPGA / RF macro on ASIC). On flops alone no gain | S | M: UVM decode checker assumes zeroed regs (`decode_reg_checker_pkg.sv`, `decode_sva.sv:42`) |
| T2.2 | Register files write on **negedge**: half-cycle paths WB→RF and RF→ID/EX. Move to posedge write + write-through bypass | same | Removes two half-cycle paths (invisible to `ltp`, real in STA) | M | M |
| T2.3 | `FlushE` zeroes every wide ID/EX data field; only control/valid need flushing | `decode_stage.sv:258-300`, `hazard_unit.sv:166` | decode 9,094→8,178 cells; FlushE fanout ~294→~40 flops | S | Low-M: scoreboard checks `PCPlus4E`/`funct3E` on bubbles |
| T2.4 | Remove read-data gating by `CacheHit`, use one-hot (not priority) way select | `cache.sv:219-226, 253-289, 317-338, 385-394` | with T1.8: mem path 36→16 (1-way), 52→29 (16-way) | S | L |
| T2.5 | AUIPC: use `PCBranchE` (decode already computes PC+imm) instead of `PCPlus4E-4` muxed into ALU operand A | `execute_stage.sv:376, 419` | operand-A path 14→8 levels (RV32), 18→8 (RV64) | S | L |
| T2.6 | Select the final result in EX; stop carrying `PCPlus4M/W`, `CsrOutM/W` | `wb_stage.sv:55-64`, `memory_stage.sv:349-371`, `execute_stage.sv:409-413` | −128 flops (RV32) / −256 (RV64); ResultM becomes a wire, ResultW a 2:1 | M | M: ~56 refs in verification |
| T2.7 | Unroll FSQRT by `STAGES` | `flp_sqrt.sv:244` | FSQRT stalls 31→9 (+2.6k cells) | S | Low (12k vectors) |
| T2.8 | FPU simple ops (FSGNJ/FMV/compare/FCLASS/MINMAX) without a stall; `fmv/fneg/fabs` are FSGNJ aliases costing 2 stalls each | `risc_fpu.sv`, `hazard_unit.sv:96` | −2 cycles per FP move | S-M | Low-M |
| T2.9 | One shared `RoundPack` in the FPU (only one unit is busy at a time, `risc_fpu.sv:546`); remove duplicated operand/result registers | `risc_fpu.sv`, units | ~3.2k cells SP, ~6.5k DP (estimate); 1–2 cycles/op | S-M | M |
| T2.10 | Unify cache associativity on **2- or 4-way** across core and benches (16-way at 512 B is not justified; H&P App. B: 8-way ≈ fully associative, 2:1 rule) | `riscv_processor.sv:30`, `shared_pkg.sv:390` | 16-way costs +9.7% DCache cells and 20→45 levels; 4-way in the recoded cache costs ~+0.9k cells, +1 level | S | L-M: core never simulated set-associative |
| T2.11 | AMO MIN/MAX/MINU/MAXU via one subtractor | `amo_unit.sv:47-50` | 1,163→809 cells | S | Formally equivalent at 32 bits |
| T2.12 | Fix false load-use stalls: rs1 not zeroed for FP ops whose rs1 is an FPR, or CSR*I (uimm) | `decode_stage.sv:355` | CPI, small | S | Low |
| T2.13 | `mcause` stored as interrupt bit + 5-bit code (WLRL allows) | `csr_file.sv` | −26 / −58 flops | S | M: RAL tests expect full-width readback |

### Tier 3: architectural (only when goals require it)

| # | Change | Why / when |
|---|---|---|
| T3.1 | Resolve JAL in decode (target `PCBranchD` already ready) | −1 cycle per JAL (~2–4% CPI, estimate). EX redirect/trap must win over decode redirect |
| T3.2 | I-cache miss stalls only F, bubbles IF/ID (today any miss freezes F..W via `MemStall`, `hazard_unit.sv:97,160-164`) | Likely top non-FPU path after Tier 1, plus CPI. High risk: refill with PC moving |
| T3.3 | Victim buffer (dirty miss 9→3 cycles), critical-word-first, hit-under-refill | CPI on misses (`cache.sv:881-970`). Worth it when caches grow |
| T3.4 | SRAM-backed caches with registered (sync) read | Mandatory once caches grow to Linux-class 4–16 KiB: at 2 KiB the current coding is **208.7k cells** for the D-cache alone vs 9.0k + SRAM recoded |
| T3.5 | Unified FMA datapath (FADD/FMUL as FMA special cases, iterative div/sqrt shared) | FMA is **required** by F and is missing. Lowest-area route also serves D (Berkeley HardFloat `MulAddRecFN`, FPnew ADDMUL) |
| T3.6 | Register the miss signal (stall one cycle later) | Only after the FPU path is fixed |
| T3.7 | Branch prediction | **Not recommended yet.** Ibex static BTFN: CoreMark/MHz −0.2..+6.4% but fmax 500→391 MHz (CARRV 2021). Measure IPC first; T3.1 is the safe first step |

### What the critical path looks like after Tier 1

| Block | Before | After Tier 1 |
|---|---:|---:|
| FPU multiplier | 1,054 | ~165 (now worst) |
| FPU adder / divider | 559 / 551 | 132 / 126 |
| Integer ALU incl. mul | 476 | ~40–50 |
| Integer divider | 462 | 34 |
| Memory stage | 36 | 16–24 |
| CSR / decode | 28 / 28 | unchanged |

Next steps after Tier 1: split the ~165-level FPU cycle with one more internal register
(FPU is already multi-cycle, so this costs no CPI on most ops), and take the illegal-CSR check
off the trap→redirect path (`ALU.Y → CSR.Traps → Minstret` adds 15–30 levels to every ALU path).

---

## 4. Findings by subsystem

### 4.1 Caches (`cache.sv`, `memory_stage.sv`)

- **Inference blockers** (all verified):
  - whole-array next-state copy: `data = data_reg` at `:511`/`:705`, registered at `:448-450`;
  - async reset of data/tags at `:440-442`;
  - 3 write ports: store hit `:813`, refill `:998`, store-miss merge `:1020`, plus byte-merge read-modify-write `MergeBytes` `:186`;
  - 4+ asynchronous read ports `:276/284/330/335`, `:897-930`.
- Policy today: blocking, write-back + write-allocate, true-LRU ages (128 flops at 16-way), one AXI transaction at a time, 4-beat INCR bursts.
- Miss cost (zero-wait memory): clean miss 3–6 cycles, store miss 6, dirty miss 9.
- Dead logic: `lru_way_empty*`, `and_valid_bits` written, never read (synthesis removes them; cleanup only).
- Load/store alignment (`memory_stage.sv:168-206`): 209 cells, 6 levels. No action.
- SC reservation compare feeds `CacheWriteEnM → CacheHit → MemStall` (16-level cone, `memory_stage.sv:214`). Low priority.

### 4.2 FPU (`risc_fpu.sv`, `flp_*.sv`)

- Behaviour today: blocking (F/D/E stall until `done`). Stall cycles: FADD 6, FMUL 11, FDIV 11, FSQRT 31, simple ops 2.
- `STAGES` is not a pipeline depth: it spreads the mul/div iterations over cycles (`flp_mul.sv:489-491`, `flp_div.sv:528-530`). sqrt ignores it.
- Adder: single path, no LZA/LZC, rounding in the same cycle as the add. After T1.1 a dual-path adder or LZA is not justified.
- Multiplier: radix-2 Booth with a variable barrel shift every step (`flp_mul.sv:561`).
- Divider: radix-2 non-restoring. Sqrt: restoring, 1 bit/cycle.
- Duplication: 5 copies of `classify_value` (one unused, `risc_fpu.sv:269`). The adder calls `RoundPack` twice (`:612`, `:667`).
- Sharing the integer `wallace_tree` for the mantissa product (ALU idle while EX stalls on FP): ~3.6k cells at SP, **~17.8k for D on RV64**.
- Shared div/sqrt digit recurrence (Ercegovac & Lang; PULP `fpu_div_sqrt_mvp` used by FPnew): ~1.5–2.5k cells (estimate).

### 4.3 Integer execute (`risc_alu.sv`, `wallace_tree.sv`, `non_restoring_divider.sv`, `csr_file.sv`, `amo_unit.sv`)

- MUL and DIV are single-cycle combinational in EX with no stall (`hazard_unit.sv:160-168` stalls only for load-use, FPU, miss).
- ALU has 4 carry chains (ADD, SUB, signed <, unsigned <) and 3 barrel shifters. Branches reuse SUB/SLTU but read them **after** the result mux (`risc_alu.sv:133-142`), which is why `branch_true` waits on the divider.
- JALR target, load/store address and misalignment traps come from `ALUOutE` (`execute_stage.sv:403, 420, 436-467`); `PCSrcE` depends on `TrapTaken`.
- Combined T1.3 + T1.4 + T1.6: ALU 21.0k→8.0k cells (RV32, −62%), 79k→26k (RV64, −67%).
- CSR: 298 flops at RV32 (128 are the mandatory 64-bit counters). Fine.
- AMO runs in MEM with registered operands; off the critical path. Do not share the EX ALU.
- Not recommended: sharing the 25-bit FPU divider with the integer divider (saves ~1–2k cells, couples two verification envs).

### 4.4 Front end, decode, hazard, pipeline registers

- `fetch_stage`, `pc_adder`, decoders, `risc_mux*`, `hazard_unit`: already minimal. Decoders total 502 cells.
- `fetch_stage.sv:177`: `PCPlus4D <= '0` on FlushD is unnecessary. The NOP injection must stay (decode controls are not gated by `ValidD`).
- PC is carried as PC+4 and decremented twice (`decode_stage.sv:385`, `execute_stage.sv:419`): −169 cells if PC is carried instead. Low priority.
- Rs1D/Rs2D zeroing sits in series with the RF read select (`decode_stage.sv:352-358`). Low.
- No W→M store-data forwarding: load followed by store of the loaded value always stalls (`hazard_unit.sv:87`). Low.
- Duplicate pipeline fields (`RdFE`=`RdE`; `funct3E`/`RoundModeE`/`CsrOperationE` same bits) are already removed by synthesis. Cleanup only.
- `risc_mux3` is 4:1 and `risc_mux4` is 8:1 (names off by one, no cost).

---

## 5. RV64 and D-extension readiness

- What scales badly: combinational divider (3.9×, becomes critical path), multiplier (3.85×), caches (1.97×), register file (1.97×).
- D precision as written: ~138k FPU cells, FMUL depth 2,282. With T1.1/T1.2/T1.7: ~55k. The DP divider then becomes the FPU critical path (333 levels; 15 steps/cycle at `STAGES=4`) and DP sqrt stalls 60 cycles without T2.7.
- 32-bit hard-coding that blocks D: `FloatToInt`/`IntToFloat` (`risc_fpu.sv:106-247`), `execute_stage.sv:178` (FPU fixed to `SINGLE`), `:402`.
- Stale comment: `shared_pkg.sv:213` says sqrt has no DP version; it does synthesize for DOUBLE (not numerically checked).

---

## 6. Guidance for future modules

Recommendations for the blocks in `Documentation/Spec/linux/modules/`, chosen for minimal area that still boots Linux.
Sources were opened by the research agent (44 primary sources). The full table with URLs is in the agent's report (§10).

| Block | Recommended choice | Evidence from reference cores / spec |
|---|---|---|
| Trap/commit | Commit at M as planned. Carry `ExcValid`/`ExcCause` with PC and select `tval` once at M instead of piping `ExcTval`. Register the trap redirect. WFI = NOP | Priv spec allows WFI as NOP |
| TLB | Flop-based, fully associative, 4 entries (repo spec's 8 also fine), round-robin, **no ASID**, flush-all on any SFENCE.VMA; size PPN to `PADDR_W` (~49 flops/entry Sv32) | VexRiscv Linux: `portTlbSize = 4`; CVA6 Sv32 2+2 + shared; Rocket 32 + 4 superpage |
| PTW | One FSM shared by I and D, walking through the D-cache CPU port; read-only (Svade); no PTE cache | Rocket, CVA6, VexRiscv all share the D-side port |
| Cache maintenance | Clear valid bits in one cycle (they are flops). D-flush reuses the write-back burst. Uncached = one beat. Bus error completes the access and pulses an error | Ibex walks tags only because its tags are in RAM |
| PMP | Start with 0 entries (legal). Later 4–8 working entries with granularity G=1, which removes access-size input and partial-match logic | Ibex `ibex_pmp.sv`; spec: 0/16/64 CSRs |
| AXI + PMA | 2:1 fixed-priority arbiter → 1:N demux + decode-error slave. **No crossbar** (blocking core). One address-map table in `shared_pkg` used by demux and `pma.sv` | pulp-platform/axi split |
| CLINT | 64-bit `mtime` += 1 per tick from a compile-time divider; no step/prescaler registers; `mtimecmp` resets to all ones | Spec; CVA6 `clint.sv` |
| PLIC | 1-bit priorities/threshold (claim = lowest-ID priority encoder); flops only for wired sources; build after first boot shell | PLIC spec allows hardwired priorities; OpenTitan: priority width dominates area |
| UART 16550 | One-byte RX holding register; TX instantaneous in sim | — |
| Boot ROM | A few words as a `case` with registered read | — |
| C extension | CVA6-style realigner (16-bit holding reg + flag) and combinational expander at end of F; decode unchanged; +1 cycle on misaligned 32-bit branch targets | Ibex, CV32E40P expand in IF. CARRV 2021: C costs ~1% performance, saves ~30% code |
| D extension | One FP64 FMA datapath (FADD/FMUL as special cases, round to S or D) + iterative div/sqrt, replacing `flp_add_sub`/`flp_mul`. The alternative is vendoring CVFPU (adds a dependency; your call) | Rocket runs FADD/FMUL on its FMA; CVFPU: merged slices give best area |

### 6.1 Cross-cutting RTL rules (for existing and all future modules)

1. **Reset control state only** (valid bits, FSM state, PC, CSRs). Never reset datapath registers or arrays.
   AMD UG949: "Memory arrays should not be reset"; resets are "generally less necessary on the data path logic".
   **This conflicts with the module template in `Documentation/Notes/PLAN_B_LINUX.md` §3.2**, which resets every register; the template should be amended before new blocks are written.
2. **Arrays larger than a few entries use one-write, one-read, synchronous-read memory style**, written only in `always_ff`. Never copy a whole array in `always_comb` and patch it. That pattern is the single biggest area cost in this design today.
3. **No serial `for` loops that carry a data dependency** (shift-until-normalized, ripple divide). They unroll into logic chains hundreds of levels deep. Use LZC + barrel shift, or iterate across clock cycles.
4. **Decisions come from the earliest signal, not the final result mux** (branch from the adder, address from the adder, stall from registered state where possible).
5. **Register module outputs at stage boundaries** (lowRISC style guide). No single-cycle path TLB → PMP → cache → hazard → PC without a timing check.
6. **FSMs as enum + two processes**; let synthesis pick the encoding.
7. **Parameterize once** (`XLEN`, `PADDR_W`, `FLEN`); no duplicated 32/64 logic; no hard-coded `32'h…` constants in width-parameterized units (see the DP NaN bug in §8).
8. **Use the smallest spec-legal option** (no ASID, PMP G≥1, 1-bit PLIC priority, Svade, global SFENCE, WFI as NOP).
9. **Every PPA change ships with an equivalence check** (Yosys SAT miter at a reduced width) in addition to the regressions, as the research agents did here.
10. **Track area and depth per module in CI**: run the hierarchical Yosys stat + `ltp` (§1) after each change so regressions are visible.

---

## 7. Benchmark reference points

| Core | Config | Area | fmax | Perf | Source |
|---|---|---|---|---|---|
| Ibex default | 2-stage RV32IMC, TSMC 65 nm | 23.72 kGE @100 MHz | 500 MHz | 2.07 CoreMark/MHz | CARRV 2021 (Gallmann et al.) |
| Ibex + WB stage + 1-cycle mul | TSMC 65 nm | 28.18 kGE | 495 MHz | 2.81 CoreMark/MHz | CARRV 2021 |
| CV32E40P | 4-stage | 53.64 kGE | 453 MHz | — | agent source |
| VexRiscv Linux balanced | RV32IMA, MMU, S-mode, 4 KB I$/D$, static BP, Artix-7 | **2883 LUT / 2130 FF** | **180 MHz** | 1.21 DMIPS/MHz, 2.27 CoreMark/MHz | VexRiscv README (re-verified verbatim) |
| VexRiscv small | RV32I, Artix-7 | 504 LUT / 505 FF | 243 MHz | 0.52 DMIPS/MHz | VexRiscv README |
| PicoRV32 | — | 761–2019 LUT | — | CPI ~4 | agent source |
| SERV | bit-serial | 125 LUT, 2.1 kGE | — | — | agent source |

Suggested targets for this core:
- **FPGA:** VexRiscv Linux-balanced class, ~3k LUT, 150–180 MHz, excluding the FPU.
- **ASIC:** between Ibex maxperf (~30 kGE) and CV32E40P (~54 kGE), excluding FPU and cache SRAM.
- Today the core is ~311k NAND2-eq (generic, not liberty-mapped), so it is roughly 6–10× above that class; Tier 1 closes most of the gap.

---

## 8. Functional issues found along the way (not PPA, but real)

| Issue | Evidence | Severity |
|---|---|---|
| **`fflags` never records FP exceptions**: FPU flags reach W and connect to nothing; `csr_file` has no flag input (only CSR writes set `Fflags`) | `riscv_processor.sv:229-234`, `csr_file.sv:302` | High for F compliance |
| **FMA family (FMADD/FMSUB/FNMADD/FNMSUB) not implemented**, required by F | no opcode `1000011..1001111` in `Design/` | High for F compliance |
| DP NaN constant is 32-bit (`32'h7FC0_0000`), becomes a subnormal pattern in DOUBLE | `flp_div.sv:360,367` | Medium (blocks D) |
| Full core never simulated with a set-associative cache | `riscv_processor.sv:30` vs `shared_pkg.sv:390` | Medium (verification gap) |
| False load-use stalls on FP-rs1 and CSR*I | `decode_stage.sv:355` | Low (CPI) |

---

## 9. Fact-check log

What the orchestrator verified against the RTL, and what it corrected.

| Claim | Agent | Verdict |
|---|---|---|
| Caches built direct-mapped (`CACHE_WAY = 1`) | measurement, memory | **Confirmed** `riscv_processor.sv:30` |
| "Existing caches use 16 ways with true LRU" | future-modules | **Corrected**: true only in unit benches; the core is direct-mapped |
| Whole-array copy + async reset in cache | measurement, memory | Confirmed `cache.sv:438-452` |
| Store-hit bypass on `CPUReadData` | memory | Confirmed `cache.sv:278-281` |
| Serial normalize loops in FPU | measurement, FPU | Confirmed `flp_mul.sv:425-432`, `flp_add_sub.sv:200-218` |
| Combinational ripple divider | measurement, int-exec | Confirmed `non_restoring_divider.sv:40-53` |
| No mul/div stall | int-exec | Confirmed `hazard_unit.sv:158-168` |
| `branch_true` reads result mux `Y` | int-exec | Confirmed `risc_alu.sv:133-142` |
| AUIPC via `PCPlus4E - 4` | int-exec, front end | Confirmed `execute_stage.sv:376, 419` |
| 4 comparators in AMO | int-exec, memory | Confirmed `amo_unit.sv:47-50` |
| Register files: negedge write + full reset | front end, measurement | Confirmed `risc_mem.sv` |
| FMA missing, DP NaN constant | FPU | Confirmed (grep, `flp_div.sv`) |
| fflags unconnected | front end | Confirmed |
| PLAN_B §3.2 template resets every register | future-modules | Confirmed |
| VexRiscv 2883 LUT / 2130 FF / 180 MHz | future-modules | **Re-verified verbatim** against the README |
| Whole-chip worst depth: 1,054 vs 1,448/1,449 | measurement vs int-exec/front end | **Discrepancy explained**: the 1,054 figure is from the hierarchical run, 1,448 from the existing flat `Syn/Yosys/out_rv32` netlist (different optimization structure). Both locate the path in `FPU.mul_unit`; conclusions unchanged. This report uses the hierarchical numbers consistently |
| "Caches 44%" vs "52%" | memory vs measurement | Not a conflict: 44% of cells, 52% of NAND2-eq weighted area |

Not independently re-verified: the CARRV 2021 numbers, CV32E40P/PicoRV32/SERV figures and other web-sourced
reference-core details (URLs exist in the agent report). Combined savings in §0 are a sum of per-module
measurements, not one joint synthesis. Cache and FPU prototypes passed only the checks stated, not project regressions.

---

## 10. Artifacts

Scratch work (scripts, prototypes, miters, logs) is in the session scratchpad and may be cleared on reboot:

- `/tmp/claude-1000/-home-marwan-ahmed-Work-RiscV/e5bf4633-d67b-44ba-8d77-4b8abaf79fca/scratchpad/measure/`: `hier32.ys`, `hier64.ys`, `stat2table.py`, `ltp.sh`, per-module stats and depth reports
- `.../scratchpad/syn/`: cache prototypes `v1..v4/cache.sv`, FPU modified units `mod/`, `rp_fast_fn.svh` (log-depth RoundPack), SAT miters
- `.../scratchpad/intexec/`: shared-adder ALU, iterative dividers, equivalence logs
- `.../scratchpad/lat/`, `.../scratchpad/sim/`: latency and cache testbenches
- Detailed agent reports: `future_REPORT.md`, `intexec_REPORT.md`, `fpu_REPORT.md`, `mem_REPORT.md`, `frontend_REPORT.md` in the scratchpad root

---

## 11. Implemented and verified (2026-11-18)

Each fix was built and regressed in its own isolated copy of the repo, then merged (disjoint files) and
regressed again as one design. Not committed.

### 11.1 Changes

| Fix | Files | What changed |
|---|---|---|
| T1.1 + T1.2 FPU log-depth normalize | `flp_add_sub.sv`, `flp_mul.sv`, `flp_div.sv` | `RoundPack` normalize/denormalize loops and the FMUL pre-normalize loop shift by 16/8/4/2/1 (32/64 first for DP) instead of 1 bit per step; denormalize is one variable shift with sticky OR. Three byte-identical `RoundPack` copies kept (no new include, so Vivado/`add_files.do` flows are unaffected). Bit- and cycle-identical |
| T1.3 iterative integer divider | `non_restoring_divider.sv` (rewritten), `risc_alu.sv`, `execute_stage.sv`, `riscv_processor.sv`, `hazard_unit.sv` (comments only) | 2 quotient bits/cycle; a divide holds EX for XLEN/2+2 cycles (18 at RV32, 34 at RV64). Busy is ORed into the existing FPU wait (`.FPUValidE(FPUValidE \|\| DivWaitE)`), so no new hazard ports. `hold = StallE` keeps the result through a cache freeze (same pattern as the FPU D32 fix) |
| T1.5 + T1.8 cache array recode | `cache.sv` | Data/tags written only in `always_ff`, one byte-enabled write port, no reset on data/tags; one read port shared by CPU reads and write-back; read-through word is a register. Store-hit `CPUReadData` bypass removed. Extra, exact: OR-encoded `hit_way` (one-hot, cache_sva A1) and flat read-select. Required: direct-mapped read data gated by `hit_array[0]` (data has no reset, so unaccessed cycles must not read X) |
| TB (needed by multi-cycle divide) | `Verification/Execute/execute_top.sv`, `execute_predictor_pkg.sv` | Standalone EX bench's hazard emulation includes `DivWaitE` like the FPU wait; predictor uses the divide's issue-cycle result like the existing FPU model. The old predictor failed execute_top with the new RTL (100/75 errors), so the change is required. No check weakened |

### 11.2 Verification

| Check | Baseline | Merged design |
|---|---|---|
| UVM unit + full-core tops (9 tops × XLEN 32/64 × seeds 1234/777) | 36/36 PASS | **36/36 PASS**, 0 UVM_ERROR/FATAL |
| Full core vs internal ISS and Spike, lock-step | 0 mismatches | **0 mismatches** (456–519 commits per run, traps and interrupts included) |
| riscv-tests compliance | 171/195 | **171/195**, identical fail set (24: missing FLW/FSW decode, FMA, FENCE.I, misaligned, PMP, breakpoint) |
| rv32um / rv64um (all DIV/REM incl. W forms) | PASS | PASS |
| Merged functional coverage per covergroup, both XLEN | — | **identical** to baseline |
| FPU formal | — | `RoundPack` and the FMUL loop SAT-proven equivalent on the final files (SP and DP); whole `flp_add_sub` proven by induction (415/415 SP, 979/979 DP) |
| Divider standalone | — | vs. original combinational module: exhaustive at 8 bits (131,072 cases), 20,072 corner+random at 32 and 64 bits, 0 mismatches |

Note: per-seed coverage of `execute_top` is lower (e.g. RV64 90.6% → 88.3%) because each divide now
consumes 34 cycles of a fixed-length run; merged over both seeds every covergroup reaches the baseline value.

### 11.3 Measured result (same Yosys flow as §1, hierarchical)

| | Before | After |
|---|---:|---:|
| RV32 core cells, arrays inferred as `$mem` | 146,812 | **57,827** + 4 `$mem` (−61%) |
| RV32 core cells, arrays mapped to flops | 146,812 | **77,113** (−47%) |
| RV32 NAND2-eq, flops | 311k | 167k (−46%) |
| RV64 core cells, arrays as `$mem` | 275,910 | **98,079** + `$mem` (−64%) |
| Worst path RV32 / RV64 (gate levels) | 1,054 / 1,146 | **159 / 159** |
| Worst path location | FPU mul normalize / integer divider | FPU mul `RoundPack` → `result_reg` |

### 11.4 Behaviour changes and residual risk

- DIV/REM latency: +17 cycles (RV32), +33 (RV64); interrupts wait for an in-flight divide. No early-out yet (`lzc_wr.sv` could add one).
- Hazard input `FPUValidE` now also carries a waiting divide (documented in `hazard_unit.sv`).
- Cache data/tags are X after reset in simulation; every reader is qualified by valid (and dirty for write-back). The future flush walk (CACHE_MAINTENANCE.md) must keep that qualification.
- `CPUReadData` on non-load cycles changed (old word on store hit, `'0` when idle). Not architectural.
- Cache reads are still asynchronous: LUTRAM-friendly, not SRAM/BRAM-ready (needs T3.4).
- Not run: Vivado synthesis, real STA.
- Next critical path: FPU multiplier at 159 levels. After that, the integer path `PCPlus4E → AUIPC → ALU/mul → misaligned trap → Minstret` (114 levels with FPU stubbed), addressed by T1.4, T1.6 and T2.5.
