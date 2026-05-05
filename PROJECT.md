# RISC-V 5-Stage Pipeline Processor Project

## Project Overview

This is a complete RISC-V 5-stage pipeline processor implementation with:
- RV32I base integer instruction set
- RV32M multiply/divide extension
- RV32F single-precision floating-point extension
- Machine-mode CSR support
- Full UVM verification environment

## Directory Structure

```
RiscV/
├── Design/                          # RTL Design Files (SystemVerilog)
│   ├── shared_pkg.sv               # Shared types, enums, parameters
│   ├── csr_defs.sv                 # CSR register definitions and masks
│   │
│   ├── fetch_stage.sv             # Instruction Fetch stage
│   ├── decode_stage.sv            # Instruction Decode stage
│   ├── execute_stage.sv           # Execute stage (ALU + FPU)
│   ├── memory_stage.sv            # Memory access stage
│   ├── wb_stage.sv                # Write-back stage
│   │
│   ├── riscv_processor.sv         # Top-level processor integration
│   ├── hazard_unit.sv             # Hazard detection and forwarding
│   │
│   ├── risc_control_unit.sv       # Control unit (decoders)
│   ├── opcode_decoder.sv          # Opcode decoding
│   ├── alu_decoder.sv             # ALU function decoding
│   ├── fpu_decoder.sv            # FPU instruction decoding
│   │
│   ├── risc_alu.sv                # Arithmetic Logic Unit
│   ├── risc_reg_file.sv           # Integer register file (32x32)
│   ├── fp_reg_file.sv             # Floating-point register file
│   ├── risc_instruction_memory.sv # Instruction ROM
│   ├── risc_data_memory.sv        # Data memory (RAM)
│   ├── data_memory.sv             # Data memory wrapper
│   ├── risc_mem.sv                # Single-port memory cell
│   │
│   ├── csr_file.sv                # Control and Status Registers
│   │
│   ├── risc_fpu.sv               # Floating-Point Unit wrapper
│   ├── flp_add_sub.sv            # FPU addition/subtraction
│   ├── flp_mul.sv                # FPU multiplication
│   ├── flp_div.sv                # FPU division
│   ├── flp_sqrt.sv               # FPU square root
│   │
│   ├── wallace_tree.sv           # Wallace tree multiplier
│   ├── non_restoring_divider.sv  # Non-restoring divider
│   ├── lzc_wr.sv                # Leading zero counter
│   │
│   ├── risc_mux2.sv              # 2-to-1 multiplexer
│   ├── risc_mux3.sv              # 4-to-1 multiplexer
│   ├── risc_mux4.sv              # 8-to-1 multiplexer
│   └── pc_adder.sv               # PC+4 adder
│
├── Verification/                   # UVM Verification Environment
│   │
│   ├── Risc/                     # Full processor verification
│   │   ├── risc_top.sv           # Top-level testbench
│   │   ├── risc_interface.sv     # Processor interface
│   │   ├── risc_test_pkg.sv      # Test package
│   │   └── *.sv                  # Verification components
│   │
│   ├── Fetch/                    # Fetch stage verification
│   │   ├── fetch_top.sv          # Top-level testbench
│   │   ├── fetch_interface.sv    # Stage interface
│   │   ├── fetch_item_pkg.sv     # Sequence item
│   │   ├── fetch_driver_pkg.sv   # Driver
│   │   ├── fetch_monitor_pkg.sv  # Monitor
│   │   ├── fetch_seq_pkg.sv      # Sequences
│   │   ├── fetch_agent_pkg.sv    # Agent
│   │   ├── fetch_env_pkg.sv      # Environment
│   │   ├── fetch_scoreboard_pkg.sv  # Scoreboard
│   │   ├── fetch_subscriber_pkg.sv   # Subscriber
│   │   ├── fetch_config_pkg.sv   # Configuration
│   │   └── fetch_test_pkg.sv     # Test package
│   │
│   ├── Decode/                   # Decode stage verification
│   │
│   ├── Execute/                  # Execute stage verification
│   │
│   ├── Memory/                  # Memory stage verification
│   │
│   ├── WriteBack/               # Write-back stage verification
│   │
│   ├── FPU/                    # FPU verification
│   │
│   ├── CSR/                    # CSR verification
│   │
│   └── Hazard/                 # Hazard unit verification
│
├── Python/                      # Test program generation
│   ├── riscv_testcase_generator.py  # Python test generator
│   ├── sample_output/           # Sample hex output files
│   └── hex1.v                  # Hex file example
│
├── vault/                      # Documentation and backups
│
├── COMMENTING_STYLE.md         # Commenting conventions
├── CODE_STYLE.md              # Code style guide
└── README.md                  # Project README
```

## Pipeline Architecture

### 5-Stage Pipeline
1. **Fetch (F)**: Instruction fetch from memory, PC+4 calculation
2. **Decode (D)**: Instruction decode, register read, immediate extraction
3. **Execute (E)**: ALU/FPU execution, branch comparison, address calculation
4. **Memory (M)**: Data memory access for loads/stores
5. **Write-Back (W)**: Register file update, PC selection

### Key Features
- **Hazard Detection**: Load-use stall, branch stall, FPU busy stall
- **Forwarding**: GPR and FPR forwarding from MEM and WB stages
- **Control Flow**: JAL, JALR, conditional branches
- **Interrupts**: Machine timer, software, and external interrupts
- **Traps**: Exception and trap handling via CSR

## Design Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| DATA_WIDTH | 32 | Data path width |
| ADDR_WIDTH | 32 | Address space (configurable) |
| PRECISION | SINGLE | Floating-point precision |
| STAGES | 4 | FPU pipeline stages |

## Instruction Extensions

- **RV32I**: Base integer ISA (ADD, SUB, AND, OR, XOR, SLT, shifts, etc.)
- **RV32M**: Multiply/Divide extension (MUL, DIV, REM, etc.)
- **RV32F**: Single-precision floating-point (FADD, FMUL, FCVT, etc.)

## Verification Strategy

Each pipeline stage has a complete UVM verification environment with:
- **Agent**: Driver, Monitor, Sequencer
- **Sequence**: Randomized stimulus generation
- **Scoreboard**: Expected vs actual comparison
- **Subscriber**: Coverage collection
- **Environment**: Integration of all components

## Build and Simulation

Refer to individual testbench `*_top.sv` files for simulation setup.

## Documentation

- `COMMENTING_STYLE.md`: Detailed commenting conventions
- `vault/`: Additional design documentation