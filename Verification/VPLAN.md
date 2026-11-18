# Verification Plan

What the RISC-V core must do, and for each feature: the stimulus that exercises
it, the checker that decides pass/fail, and the coverage that proves the
stimulus reached it. A feature is **closed** when its checker reports no error
over a full regression and its coverage items are at 100 % (or each hole has a
written waiver).

Status is from `Questa/regress.sh -c` (merged coverage per XLEN, see
[Status](#status)).

## Verification levels

| Level | Where | Stimulus | Checking |
|---|---|---|---|
| Unit | `<Unit>/<unit>_top.sv` | Constrained-random items (`<unit>_seq`) | Predictor + in-order scoreboard, RAL backdoor checkers, SVA |
| Full core | `Risc/risc_top.sv`, `risc_test` | Random programs (`Python/riscv_testcase_generator.py`) + random interrupts | `commit_checker`: every commit vs the in-house ISS, ISS vs Spike (`+SPIKE`), all unit environments passive, SVA |
| ISA compliance | `Risc/risc_top.sv`, `risc_compliance_test` | riscv-tests `rv<XLEN>{ui,um,ua,uf,mi}-p-*` (`Compliance/build_tests.py`) | Self-checking `tohost` value + ISS lock-step |
| Protocol | `Protocol/AXI_Assertions.sv` | Any of the above | AXI channel rules on the I/D master ports |

Every level runs at XLEN 32 and 64.

## Features

ID prefixes: IF fetch, ID decode, EX execute, FP FPU, CS CSR/traps, MEM memory,
WB write-back, HZ hazards, CORE full core, ISA compliance.

### Fetch (`Fetch/`)

| ID | Feature | Stimulus | Checker | Coverage (`fetch_subscriber`) |
|---|---|---|---|---|
| IF-1 | PC sequencing, redirect on branch/jump/trap | `fetch_seq` | `fetch_predictor` + `fetch_scoreboard`; `fetch_sva` | `PCF_align_cg` |
| IF-2 | IF/ID stall and flush | `fetch_seq` | scoreboard; `fetch_sva` | `StallD_cg`, `FlushD_cg`, `StallBit_cg`, `FlushBit_cg`, `Stall_x_Flush_cx`, `StallBit_x_FlushBit_cx` |
| IF-3 | I-cache hit / miss refill over AXI | `fetch_seq` | scoreboard; `cache_sva`; `AXI_Assertions` | `CacheHitF_cg`, `CacheHit_x_Flush_cx` |
| IF-4 | Instruction memory holds the program image | test start | `fetch_mem_checker` (RAL backdoor) | n/a |

### Decode (`Decode/`)

| ID | Feature | Stimulus | Checker | Coverage (`decode_subscriber`) |
|---|---|---|---|---|
| ID-1 | Opcode to control signals (RV I/M/A/F, Zicsr, system) | `decode_seq` | `decode_predictor` + scoreboard | `opcode_cg`, `ALUControlE_cg`, `FPUControlE_cg`, `AmoOpE_cg`, `CsrOperationE_cg`, `SelectorE_cg`, `opcode_x_Selector_cx` |
| ID-2 | GPR/FPR read and write-back, x0 hard-wired | `decode_seq` | `decode_reg_checker` (RAL backdoor, final sweep) | `Rs1D_cg`, `Rs2D_cg`, `RdW_cg`, `RegWriteW_cg`, `FPURegWriteW_cg` |
| ID-3 | Illegal instruction, ECALL, EBREAK, MRET detection | `decode_seq` | scoreboard | `IllegaleInstructionE_cg`, `EcallE_cg`, `EbreakE_cg`, `MRetE_cg` |
| ID-4 | ID/EX stall and flush | `decode_seq` | scoreboard; `decode_sva` | `StallE_cg`, `FlushE_cg`, `ValidE_cg` |

### Execute (`Execute/`)

| ID | Feature | Stimulus | Checker | Coverage (`execute_subscriber`) |
|---|---|---|---|---|
| EX-1 | ALU and M-extension operations | `execute_seq` | `execute_predictor` + scoreboard | `ALUControlE_cg`, `RD1E_cg` and operand points |
| EX-2 | Branch resolution and PC redirect | `execute_seq` | scoreboard; `execute_sva` | `BranchE_cg`, `JumpE_cg`, `funct3E_cg`, `PCSrcE_cg` |
| EX-3 | Integer and FP operand forwarding | `execute_seq` | scoreboard | `ForwardAE_cg`, `ForwardBE_cg`, `ForwardFloatingAE_cg`, `ForwardFloatingBE_cg` |
| EX-4 | FPU and CSR file inside the stage | `execute_seq` | passive `flp_env`, `csr_env` | see FP, CS |

### FPU (`FPU/`)

| ID | Feature | Stimulus | Checker | Coverage (`flp_subscriber`) |
|---|---|---|---|---|
| FP-1 | Add/sub/mul/div/sqrt in every rounding mode | `flp_seq` | `flp_predictor` (SV model or DPI golden `+FLP_DPI`) + scoreboard | `operation_cg`, `round_mode_cg`, `operation_x_round_cx` |
| FP-2 | IEEE operand classes (zeros, inf, NaN, subnormal, binade edges) | `flp_seq` corner values | scoreboard | `InA_class_cg`, `InB_class_cg`, `InA_x_InB_class_cx` |
| FP-3 | Exception flags | `flp_seq` | scoreboard | `Overflow_cg`, `Underflow_cg`, `NaN_cg`, `Inf_cg`, `Zero_cg`, `InvalidDiv_cg` |
| FP-4 | Multi-cycle valid/busy/done handshake, hold | `flp_seq` | `flp_monitor` pairing; `fpu_sva` | `valid_cg`, `busy_cg`, `done_cg` |

### CSR and traps (`CSR/`)

| ID | Feature | Stimulus | Checker | Coverage (`csr_subscriber`) |
|---|---|---|---|---|
| CS-1 | CSRRW/S/C (and immediate forms) on every implemented CSR | `csr_seq` | `csr_predictor` + scoreboard; `csr_reg_checker` (RAL) | `CsrOperation_cg`, `CsrIndex_cg`, `CsrOp_x_CsrIndex_cx` |
| CS-2 | Synchronous traps and MRET | `csr_seq` | scoreboard; `csr_sva` | `Traps_cg`, `mret_cg`, `TrapTaken_cg`, `Traps_x_mret_cx` |
| CS-3 | Timer, external and software interrupts | `csr_seq` | scoreboard | `TimerInterrupt_cg`, `ExternalInterrupt_cg`, `SoftwareInterrupt_cg`, `*_x_Trap_cx` |
| CS-4 | FP rounding mode / CSR side effects | `csr_seq` | scoreboard | `RoundingMode_cg` |

### Memory (`Memory/`)

| ID | Feature | Stimulus | Checker | Coverage (`mem_subscriber`) |
|---|---|---|---|---|
| MEM-1 | Loads/stores of every size and lane, sign extension | `mem_seq` | `mem_flat_predictor` + scoreboard | `LoadSize_cg`, `StoreSize_cg`, `Lane_cg`, `LoadLane_cx`, `StoreLane_cx` |
| MEM-2 | D-cache hit/miss, write-back, LRU | `mem_seq`, `mem_seq_no_rst` | scoreboard; `cache_sva`; `mem_ral_checker` | `CacheHitM_cg`, `MemRead_x_CacheHit_cx`, `MemWrite_x_CacheHit_cx` |
| MEM-3 | LR/SC and AMO read-modify-write | `mem_seq` | predictor (reservation, RMW) | `AmoOp_cg`, `AmoSize_cg` |
| MEM-4 | AXI data port protocol | all | `AXI_Assertions`; `memory_sva` | assertion coverage |

### Write-back (`WriteBack/`)

| ID | Feature | Stimulus | Checker | Coverage (`writeback_subscriber`) |
|---|---|---|---|---|
| WB-1 | Result select (ALU, load, CSR, PC+4) | `writeback_seq` | `writeback_predictor` + scoreboard; `wb_sva` | `SelectorW_cg`, `ALUOutW_cg`, `ReadDataW_cg`, `CsrOutW_cg` |
| WB-2 | Redirect priority (trap over branch over stall) | `writeback_seq` | scoreboard | `Selector_x_Trap_cx`, `PCSrc_x_Stall_cx` |

### Hazards (`Hazard/`)

| ID | Feature | Stimulus | Checker | Coverage (`hazard_subscriber`) |
|---|---|---|---|---|
| HZ-1 | Forwarding select, integer and FP | `hazard_seq`, `hazard_directed_seq` | `hazard_predictor` + scoreboard | `ForwardA_x_ForwardB_cx`, `ForwardFloating*_cg` |
| HZ-2 | Load-use and FPU-busy stalls | both | scoreboard; `hazard_sva` | `StallD_x_StallE_cx`, `FPUWait_x_DCacheHit_cx` |
| HZ-3 | Cache-miss stalls of every stage | both | scoreboard | `StallF/E/M/W_cg`, `ICacheHit_cg`, `DCacheHit_cg` |
| HZ-4 | Flush on redirect and trap | both | scoreboard | `FlushD/E/M_cg`, `FlushM_x_StallM_cx` |

### Full core (`Risc/`)

| ID | Feature | Stimulus | Checker | Coverage |
|---|---|---|---|---|
| CORE-1 | Architectural state matches the ISA on every commit (PC, trap, next PC, register writes, stores, trap CSRs) | `risc_test` random programs | `commit_checker` vs `riscv_iss_pkg` | unit covergroups sampled in the core (passive envs) |
| CORE-2 | The in-house ISS matches Spike | `risc_test` with `+SPIKE` | `commit_checker` `SPIKE_CHK` | n/a |
| CORE-3 | Interrupts taken at any pipeline state | `risc_test` interrupt pulses | `commit_checker` | `csr_subscriber` interrupt crosses |
| CORE-4 | Every program reaches its end in its cycle budget | `risc_test` | `risc_test` timeout, `commit_checker` end check | n/a |

### ISA compliance (`Compliance/`)

| ID | Feature | Stimulus | Checker | Coverage |
|---|---|---|---|---|
| ISA-1 | RV32I / RV64I base | `rv<XLEN>ui-p-*` | `tohost == 1` + ISS lock-step | pass count |
| ISA-2 | M extension | `rv<XLEN>um-p-*` | same | pass count |
| ISA-3 | A extension | `rv<XLEN>ua-p-*` | same | pass count |
| ISA-4 | F extension (implemented subset) | `rv<XLEN>uf-p-*` | same | pass count |
| ISA-5 | Machine mode CSRs and traps | `rv<XLEN>mi-p-*` | same | pass count |

## Known limits

- Programs that do not fit the 4 KiB memories are skipped by `build_tests.py`
  (`ld_st`, `lrsc`, and at XLEN 64 also `ma_data` and `st_ld`).
- Compliance runs do not use Spike: its data memory starts empty, while these
  programs preload theirs.
- There is no covergroup at the full-core level yet (instruction mix x hazard x
  trap crosses). CORE features are closed by checker results only.
- The scoreboards do not yet check, at the end of the test, that their FIFOs
  are empty and that at least one item was compared.

## Status

Measured 2026-11-17 with `Questa/regress.sh -s 1234` (all nine tops) and
`Questa/regress.sh -t "" -c` (compliance).

### Random regression, seed 1234: 18/18 pass

Merged covergroup coverage over all nine tops (`$WORK/x<xlen>/coverage.txt`):

| Covergroup | XLEN 32 | XLEN 64 |
|---|---|---|
| csr_subscriber | 100.00 % | 100.00 % |
| decode_subscriber | 100.00 % | 100.00 % |
| execute_subscriber | 99.70 % | 99.70 % |
| fetch_subscriber | 100.00 % | 100.00 % |
| flp_subscriber | 91.17 % | 91.17 % |
| hazard_subscriber | 100.00 % | 100.00 % |
| mem_subscriber | 100.00 % | 100.00 % |
| writeback_subscriber | 100.00 % | 100.00 % |

Open coverage holes: `flp_subscriber` (FP-1..FP-3) and `execute_subscriber`
(EX-1..EX-3) are not closed.

### Compliance: 171 pass, 24 fail, 6 skipped

| Suite | XLEN 32 | XLEN 64 |
|---|---|---|
| ui | 39 pass, 2 fail, 1 skip | 50 pass, 1 fail, 3 skip |
| um | 8 pass | 13 pass |
| ua | 9 pass, 1 skip | 18 pass, 1 skip |
| uf | 3 pass, 8 fail | 2 pass, 9 fail |
| mi | 14 pass, 2 fail | 15 pass, 2 fail |

Every failure is a feature the core does not implement; the ISS lock-step
reported 0 mismatches in all 195 runs, so RTL and ISS agree on each of them.
A `tohost` value of `TESTNUM | 1337` means an unexpected trap in that test case.

| Tests | Result | Cause |
|---|---|---|
| `uf-p-*` (all except `fclass`, `move` and, at XLEN 32, `fcvt`) | unexpected trap (`tohost` 1337 + case) | No FP load/store: FLW/FSW (opcodes LOAD-FP / STORE-FP) are not decoded, so the first `flw` traps as an illegal instruction (mcause 2) |
| `ui-p-fence_i` | trap before case 1 (1337) | FENCE.I is an illegal instruction (Harvard memories) |
| `rv32ui-p-ma_data` | trap before case 1 (1337) | Misaligned loads/stores trap (mcause 4) instead of completing |
| `mi-p-pmpaddr` | case 1 fails | No PMP CSRs |
| `mi-p-breakpoint` | case 2 fails | No debug trigger CSRs (`tselect`/`tdata`) |
| `ui-p-ld_st`, `ua-p-lrsc`, `rv64ui-p-ma_data`, `rv64ui-p-st_ld` | skipped | Do not fit the 4 KiB memories |
