# Questa Simulation Setup

## Overview
What is verified, by which test and checker, is in [`Verification/VPLAN.md`](../Verification/VPLAN.md).

This folder contains Questa simulation scripts for the RISC-V 5-stage pipeline processor.

## Folder Structure
```
Questa/
├── do/
│   ├── compile.do       # Compile all design and verification files (incl. RAL packages)
│   ├── add_files.do     # Add files to Questa project (scratch area)
│   ├── sim_fetch.do     # Simulate Fetch stage verification
│   ├── sim_decode.do    # Simulate Decode stage verification
│   ├── sim_execute.do   # Simulate Execute stage verification
│   ├── sim_mem.do       # Simulate Memory stage verification
│   ├── sim_writeback.do # Simulate Write-back stage verification
│   ├── sim_fpu.do       # Simulate FPU verification
│   ├── sim_csr.do       # Simulate CSR verification
│   ├── sim_hazard.do    # Simulate Hazard unit verification
│   └── sim_risc.do      # Simulate full processor verification
├── regress.sh           # Headless regression (all tops x XLEN x seeds, compliance, merged coverage)
├── Scratch/             # Local working directory (not tracked): Questa project, work library, logs, UCDBs
└── README.md            # This file
```

## Quick Start

Every script finds the repository from its own location (`[status file]` in the do files, `$0` in `regress.sh`), so they run from any directory; the work library is created in the current directory. `Questa/Scratch/` is the usual place for interactive runs.

The programs for `fetch_top` and `risc_top` are read from the directory given by their `PROGRAM_DIR` parameter (`-gPROGRAM_DIR=<dir>`, see `Verification/Common/tb_base_pkg.sv`). `sim_fetch.do` and `sim_risc.do` pass `<repo>/Python`; create the program there first with `python3 Python/riscv_testcase_generator.py --out-dir Python`. Regenerate images from older checkouts before running the full core. Its 4 KiB RAM now holds both instructions and data, and the generator places random stores above the program.

### 1. Compile All Files
```tcl
cd <repo>/Questa/Scratch
do ../do/compile.do                 # XLEN 32
set XLEN 64; do ../do/compile.do    # RV64 core
```

### 2. Add Files to Project (Scratch Area)
To add files to a new Questa project (creates files in the scratch area):
```tcl
cd <repo>/Questa/Scratch
do ../do/add_files.do
```
This adds all design and verification files to the Questa project for the scratch area where the Questasim project will be created.

### 3. Run Individual Simulations
Each `sim_*.do` recompiles, loads its `*_top`, adds waves, and runs to completion:

| Environment | Command |
|-------------|---------|
| Fetch stage | `do ../do/sim_fetch.do` |
| Decode stage | `do ../do/sim_decode.do` |
| Execute stage | `do ../do/sim_execute.do` |
| Memory stage | `do ../do/sim_mem.do` |
| Write-back stage | `do ../do/sim_writeback.do` |
| FPU | `do ../do/sim_fpu.do` |
| CSR | `do ../do/sim_csr.do` |
| Hazard unit | `do ../do/sim_hazard.do` |
| Full processor | `do ../do/sim_risc.do` |

Batch (no GUI), e.g.:
```sh
vsim -c -64 -voptargs=+acc mem_top +UVM_VERBOSITY=UVM_LOW -do "run -all; quit -f"
```

Regression (all tops × XLEN 32/64 × random seeds, one PASS/FAIL table, works in a scratch dir outside the repo):
```sh
Questa/regress.sh                          # 3 random seeds, XLEN 32 and 64, all nine tops
Questa/regress.sh -n 10                    # 10 random seeds
Questa/regress.sh -x 64 -s 1234 -t mem_top # reproduce one failing row
Questa/regress.sh -c                       # also run the riscv-tests compliance suite on risc_top
Questa/regress.sh -t "" -c                 # compliance suite only
Questa/regress.sh -t "" -f                 # upstream and directed FENCE.I tests only
```

**Merged coverage:** after the runs of each XLEN, all UCDBs are merged with `vcover merge` into `$WORK/x<xlen>/merged.ucdb`, and the end of the regression prints one coverage line per covergroup type (also in `$WORK/x<xlen>/coverage.txt`). Open the merged database with `vsim -viewcov $WORK/x32/merged.ucdb` or report it with `vcover report -details`.

**Compliance (`-c`):** `Verification/Compliance/build_tests.py` builds the riscv-tests rv<XLEN>ui/um/ua/uf/mi `-p-` programs (unmodified sources, a link script for the core's 4 KiB address space) and each one runs on `risc_top` with `+UVM_TESTNAME=risc_compliance_test`. A test passes when it writes `tohost = 1` and the ISS lock-step reports no mismatch. Needs `riscv64-unknown-elf-gcc` and the riscv-tests sources in `third_party/riscv-tests` (`git clone --recursive https://github.com/riscv-software-src/riscv-tests third_party/riscv-tests`). Programs that do not fit the address space are listed as SKIP.

`-c` also runs the local self-modifying-code test `rv<XLEN>ui-p-fence_i_smc`. Use `-f` to select that test and the upstream `rv<XLEN>ui-p-fence_i` for each requested XLEN.

**Spike lock-step (risc_top):** when `Verification/Risc/spike/libspike_dpi.so` exists, `regress.sh` and `sim_risc.do` load it with `+SPIKE`, and the commit checker steps Spike next to the in-house ISS on every commit (`SPIKE_CHK` messages). Build it with `cd Verification/Risc/spike && make` once Spike is installed (steps in that Makefile). The core profile Spike runs with is listed at the top of `spike_dpi.cc`.

`-voptargs=+acc` is required: the UVM RAL checkers (Fetch, Decode, CSR, Memory) read DUT storage through backdoor HDL paths.

**FPU DPI golden:** `sim_fpu.do` loads `Verification/FPU/dpi/libfpu_ref.so` when present. The library embeds Python, so it must be rebuilt (`cd Verification/FPU/dpi && make`) against the host's `libpython` (it is currently built for Python 3.14; a library built for another Python version fails to load and the run aborts). If the file is absent, the FPU env uses the SystemVerilog reference model.

## Simulation Flow

1. Each `sim_*.do` file:
   - Calls `compile.do` to ensure all files are compiled
   - Loads the appropriate top-level testbench
   - Adds relevant signals to the waveform viewer
   - Runs the simulation to completion (`run -all`) and saves coverage

## Waveform Signals

Each simulation do file adds specific signals to the waveform:
- **Clock and Reset**: clk, rst
- **DUT Inputs**: Stage-specific input signals
- **DUT Outputs**: Stage-specific output signals
- **Pipeline Registers**: Inter-stage pipeline values
- **Internal Signals**: Key internal signals for debugging

## Requirements

- Questa SIM (Mentor Graphics/Siemens EDA)
- UVM 1.2 (bundled with Questa; set as the default `mtiUvm` in the Questa install's modelsim.ini)
- Design source files in `Design/`, verification files in `Verification/`

## Notes

- Do files resolve paths from their own location; run them from the directory that should hold the work library
- Waveforms display top DUT signals for each verification environment
- The scratch area (`Questa/Scratch/`) is where the Questasim project and compiled libraries are stored
- Use `add_files.do` to add files to a new Questa project in the scratch area
