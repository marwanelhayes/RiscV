# Questa Simulation Setup

## Overview
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
├── Scratch/             # Working directory: Questa project, work library, logs, UCDBs
└── README.md            # This file
```

## Quick Start

All scripts use paths relative to `Questa/Scratch/` (`../../Design`, `../../Verification`, `../do`).

### 1. Compile All Files
```tcl
cd <repo>/Questa/Scratch
do ../do/compile.do
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
vsim -c -voptargs=+acc mem_top +UVM_VERBOSITY=UVM_LOW -do "run -all; quit -f"
```

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
- UVM 1.1d (bundled with Questa)
- Design source files in `Design/`, verification files in `Verification/`

## Notes

- All do files use paths relative to `Questa/Scratch/`
- Waveforms display top DUT signals for each verification environment
- The scratch area (`Questa/Scratch/`) is where the Questasim project and compiled libraries are stored
- Use `add_files.do` to add files to a new Questa project in the scratch area