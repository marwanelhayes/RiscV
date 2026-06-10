# Functional Coverage — Peripheral Verification Environments

Structural functional-coverage model for every peripheral UVM environment. Each
covergroup lives in `<env>/<env>_subscriber_pkg.sv`, is fed by the monitor's
analysis port, and uses explicit bins, crosses and `ignore_bins`/`illegal_bins`
so that every defined bin is reachable (constrained-out encodings are excluded
with a rationale, never left dangling).

## How to run

From `Questa/Scratch`:

```
vsim -c    -do "do ../do/sim_<env>.do; quit -f"     # csr decode execute fetch hazard mem writeback
vsim -64 -c -do "do ../do/sim_fpu.do; quit -f"      # FPU needs the 64-bit DPI golden lib
```

Each `sim_<env>.do` runs the test, then `coverage save <env>.ucdb` and
`coverage report -detail -output <env>_cov.txt`. Reset polarity is active-low
(`rst==1` = normal), so coverpoints sample `iff(sub_item.rst)` (CSR already did;
the others were corrected from `iff(!rst)`, which had been sampling only reset).

> Reporting note: the design compiles every subscriber package, so the Questa
> "Total coverage (filtered view)" line aggregates **all** covergroup *types*
> (and type coverage persists in the shared work library across runs). The
> authoritative per-env number is that env's own covergroup TYPE line in
> `<env>_cov.txt`: `TYPE /<env>_subscriber_pkg/<env>_subscriber/cvr_grp`.

## Coverage collected

| Environment | Functional coverage | Scoreboard | Notes |
|-------------|--------------------:|-----------:|-------|
| CSR         | **100.00%** | 0 fail | RTL bug fixed (see below) |
| Decode      | **100.00%** | 0 fail | |
| Execute     | **100.00%** | 0 fail | |
| Hazard      | **100.00%** | 0 fail | |
| Memory      | **100.00%** | 0 fail | |
| WriteBack   | **100.00%** | 0 fail | |
| FPU         | 82.70% | 72 fail | open functional bug + FP-corner stimulus (flagged) |
| Fetch       | 65.00% | 0 fail | TB connectivity issue (flagged) |

### CSR RTL fix
`Design/csr_file.sv` `UpdateCsr` took the CSR index as `[ADDR_WIDTH-1:0]`
(10 bits) while the read path used the full 12-bit `CsrIndex`. High CSR
addresses (`mhartid`, `mcycle`, `mvendorid`, `misa`) were truncated on write, so
those registers never updated and reads returned stale data — 100 scoreboard
mismatches. Fixed by widening the parameter to `csr_index_t`.

---

## Per-environment bin model

### CSR (`csr_subscriber_pkg.sv`) — 100%
- `rst_cg`: idle{0}, operating{1}
- `CsrAccess_cg` *(iff rst)*: no_access{0}, access{1}
- `CsrOperation_cg` *(iff rst && CsrAccess)*: csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci; `ignore_bins` system (never under access)
- `CsrIndex_cg` *(iff rst && CsrAccess)*: fflags, frm, fcsr, mstatus, medeleg, mideleg, mie, mtvec, mscratch, mepc, mcause, mbadaddr, mcycle, mhartid; `ignore_bins` misa/mvendorid/mip (read-only under access)
- `Traps_cg`: all 13 trap causes
- `mret_cg`, `TimerInterrupt_cg`, `ExternalInterrupt_cg`, `SoftwareInterrupt_cg`, `TrapIsSet_cg`: {0},{1}
- `RoundingMode_cg`: RNE, RTZ, RDN, RUP, RMM, DYN
- Crosses: `CsrOperation × CsrIndex`; `Traps × mret` (`ignore_bins` trap-with-mret); `{Timer,External,Software}Interrupt × TrapIsSet`

### Decode (`decode_subscriber_pkg.sv`) — 100%
- `opcode_cg`: R_TYPE, LOAD, S_TYPE, B_TYPE, I_TYPE, JAL, JALR, CSR, FLOATING_PT
- `ALUControlE_cg`: 18 ALU ops; `FPUControlE_cg`: 21 FPU ops
- `CsrOperationE_cg` (7), `CsrIndexE_cg` (17), `SelectorE_cg` (4), `MoveOperationE_cg`/`MoveOperationW_cg` (3), `RoundModeE_cg` (6), `funct3E_cg` (0-7)
- Control flags {0}/{1}: RegWriteE, FPURegWriteE, MemWriteE, BranchE, JumpE, ALUSrcE, CsrAccessE, EcallE, EbreakE, MRetE, FlushE, FPUValidE, RegWriteW, FPURegWriteW
- `IllegaleInstructionE_cg`: lo{0}; `ignore_bins` high (ValidInstructions generates only legal opcodes)
- `Rs1D_cg`, `Rs2D_cg` (all GPRs); `RdW_cg` (`ignore_bins` zero)
- Cross: `opcode × SelectorE`. (FP control×round and move×fpu-write crosses intentionally omitted — combinations are decoder-determined; covered by individual coverpoints and the FPU env.)

### Execute (`execute_subscriber_pkg.sv`) — 100%
- `ALUControlE_cg` (18), `funct3E_cg` (0-7), `CsrOperationE_cg` (7), `CsrIndexE_cg` (17), `SelectorE_cg`/`SelectorM_cg` (4), `FPUControlE_cg` (21), `RoundModeE_cg` (6), `MoveOperationE_cg` (3)
- `ForwardAE_cg`/`ForwardBE_cg`: {0,1,2,3,4}; `ForwardFloatingAE_cg`/`BE`: {0,1,2}
- Control flags {0}/{1}: BranchE, JumpE, RegWriteE, FPURegWriteE, CsrAccessE, ALUSrcE, MemWriteE, MRetE, EcallE, EbreakE, IllegaleInstructionE, Timer/Software/ExternalInterrupt, FPUValidE, PCSrcE, RegWriteM, MemWriteM, TrapIsSet
- `Rs1E_cg` (all GPRs); `RdE_cg` (`ignore_bins` zero)
- Data sign bins {neg,pos}: RD1E, RD2E, SignImmE, ALUOutM, WriteDataM
- Crosses: `ALUControl × funct3`; `funct3 × Branch`; `ForwardAE × ForwardBE`; `RegWriteE × FPURegWriteE` (`ignore_bins` both-low/both-high — `CantEqualize`)

### Hazard (`hazard_subscriber_pkg.sv`) — 100%
- `ForwardAE_cg`/`ForwardBE_cg`: none{0}, wb{1}, mem{2}, wb_fpu{3}, mem_fpu{4}
- `ForwardFloatingAE_cg`/`BE`: none{0}, wb{1}, mem{2}
- Stall/flush outputs {0}/{1}: StallD, StallF, FlushE, FlushD
- Control inputs {0}/{1}: RegWriteM, RegWriteW, FPURegWriteM, FPURegWriteW, PCSrcE, TrapIsSet, FPUValidE, FPUBusyM, ICacheHit, DCacheHit
- `SelectorE_cg` (4), `MoveOperationE_cg` (3)
- Crosses: `RegWriteM × RegWriteW`; `FPUBusyM × DCacheHit`; `ForwardAE × ForwardBE` with `ignore_bins` for integer-forward × FPU-forward mixes (both selects share `MoveOperationE`, so 17 of 25 combinations are legal)
- Directed sequence `hazard_directed_seq` biases registers into a shared set to exercise all forward sources.

### Memory (`mem_subscriber_pkg.sv`) — 100%
- `funct3M_cg`: word{W}; `ignore_bins` others (OnlyWord constraint)
- `CacheHitM_cg`: miss{0}, hit{1}
- Controls {0}/{1}: MemWriteM, RegWriteM, FPURegWriteM, RegWriteW
- `SelectorM_cg`/`SelectorW_cg` (4), `MoveOperationM_cg` (3)
- FP flags {0}/{1}: OverflowM, UnderflowM, NaNM, InfM, ZeroM, InvalidDivM
- `RdM_cg` (`ignore_bins` zero); data sign bins {neg,pos}: ALUOutM, ReadDataW, ALUOutW
- Crosses: `MemWriteM × CacheHitM`; `SelectorM × RegWriteM`

### WriteBack (`writeback_subscriber_pkg.sv`) — 100%
- `SelectorW_cg` (4); `PCSrcE_cg`, `StallF_cg`, `TrapIsSet_cg`: {0}/{1}
- Data sign bins {neg,pos}: ALUOutW, ReadDataW, CsrOutW
- Crosses: `SelectorW × TrapIsSet`; `PCSrcE × StallF`

### FPU (`flp_subscriber_pkg.sv`) — 82.70% *(flagged)*
- `operation_cg` (21), `round_mode_cg` (6), `MoveOperation_cg` (3), `valid_cg`/`RegWrite_cg` {0}/{1}
- `InA_class_cg`/`InB_class_cg`: zero, denorm, normal, inf, nan (decoded from exponent/fraction)
- Status outputs {0}/{1}: busy, done, Overflow, Underflow, NaN, Inf, Zero, InvalidDiv
- Crosses: `operation × round_mode`; `InA_class × InB_class`
- **Open items:** 72 scoreboard mismatches (FPU reference-model/RTL functional bug) and the FP-corner output/class bins (inf/zero operands, overflow/inf/zero/invalid-div flags) require directed corner stimulus that is entangled with the functional bug. Left as a separate task.

### Fetch (`fetch_subscriber_pkg.sv`) — 65.00% *(flagged)*
- `rst_cg`: active{0}, idle{1}
- {0}/{1}: StallD, FlushD, StallBit, FlushBit, CacheHitF; `PCF_align_cg`: aligned{2'b00}
- Crosses: `StallD × FlushD`; `CacheHitF × FlushD`; `StallBit × FlushBit`
- **Open items:** TB connectivity — `StallD`/`CacheHitF` are partly `X` (undriven), `CacheHitF` never returns a hit, and `StallBit`/`FlushBit` are interface-only aliases never sampled back. These are testbench wiring issues, not coverage gaps; left as a separate task.
