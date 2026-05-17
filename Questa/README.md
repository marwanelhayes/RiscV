# Questa Simulation Setup

## Overview
This folder contains Questa simulation scripts for the RISC-V 5-stage pipeline processor.

## Folder Structure
```
Questa/
├── do/
│   ├── compile.do       # Compile all design and verification files
│   ├── add_files.do     # Add files to Questa project (scratch area)
│   ├── sim_fetch.do     # Simulate Fetch stage verification
│   ├── sim_execute.do   # Simulate Execute stage verification
│   ├── sim_mem.do       # Simulate Memory stage verification
│   ├── sim_writeback.do # Simulate Write-back stage verification
│   ├── sim_fpu.do       # Simulate FPU verification
│   ├── sim_csr.do       # Simulate CSR verification
│   ├── sim_hazard.do    # Simulate Hazard unit verification
│   └── sim_risc.do      # Simulate full processor verification
└── README.md            # This file
```

## Quick Start

### 1. Compile All Files
```tcl
cd C:/marwan-ahmed/Work/RiscV/Questa/do
do compile.do
```

### 2. Add Files to Project (Scratch Area)
To add files to a new Questa project (creates files in the scratch area):
```tcl
cd C:/marwan-ahmed/Work/RiscV/Questa/do
do add_files.do
```
This adds all design and verification files to the Questa project for the scratch area where the Questasim project will be created.

### 3. Run Individual Simulations

**Fetch Stage:**
```tcl
do sim_fetch.do
```

**Execute Stage:**
```tcl
do sim_execute.do
```

**Memory Stage:**
```tcl
do sim_mem.do
```

**Write-back Stage:**
```tcl
do sim_writeback.do
```

**FPU:**
```tcl
do sim_fpu.do
```

**CSR:**
```tcl
do sim_csr.do
```

**Hazard Unit:**
```tcl
do sim_hazard.do
```

**Full Processor:**
```tcl
do sim_risc.do
```

## Simulation Flow

1. Each `sim_*.do` file:
   - Calls `compile.do` to ensure all files are compiled
   - Loads the appropriate top-level testbench
   - Adds relevant signals to the waveform viewer
   - Runs the simulation for specified time

## Waveform Signals

Each simulation do file adds specific signals to the waveform:
- **Clock and Reset**: clk, rst
- **DUT Inputs**: Stage-specific input signals
- **DUT Outputs**: Stage-specific output signals
- **Pipeline Registers**: Inter-stage pipeline values
- **Internal Signals**: Key internal signals for debugging

## Requirements

- Questa SIM (Mentor Graphics/Siemens EDA)
- Design source files in `C:/marwan-ahmed/Work/RiscV/Design/`
- Verification files in `C:/marwan-ahmed/Work/RiscV/Verification/`

## Notes

- All do files use relative paths from `C:/marwan-ahmed/Work/RiscV/`
- Waveforms display top DUT signals for each verification environment
- Simulation times are set to 1000ns (5000ns for full processor)
- Modify run times in individual do files as needed
- The scratch area (`Questa/work/`) is where the Questasim project and compiled libraries are stored
- Use `add_files.do` to add files to a new Questa project in the scratch area