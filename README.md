# RISC-V Processor Repository Guide

This repository contains a custom SystemVerilog RISC-V processor implementation, UVM-based verification environments for both the full core and individual stages, a Python random test-case generator, and checked-in simulator/synthesis artifacts.

The goal of this README is fast orientation: if you return later to modify, debug, verify, or extend the design, this file should get you to the right place quickly.

## What Is In This Repo

- `Design/`: RTL for the processor, memories, CSR block, hazard logic, ALU, FPU, and pipeline stages.
- `Verification/`: UVM environments for the full processor and for individual blocks/stages.
- `Python/`: random RISC-V program generator that emits assembly, binary, hex, and program metadata.
- `Documentation/`: reference PDFs for RISC-V ISA and related material.
- `Questa/` and `work/`: simulator-generated artifacts and projects.
- `Syn/`: Vivado synthesis project/output.

## Design Summary

The top-level RTL is [`Design/riscv_processor.sv`](/home/marwan-ahmed/Work/RiscV/Design/riscv_processor.sv). It instantiates a classic pipelined integer core plus CSR and floating-point support:

- `fetch_stage`
- `decode_stage`
- `execute_stage`
- `memory_stage`
- `wb_stage`
- `hazard_unit`

Key shared types and global parameters live in [`Design/shared_pkg.sv`](/home/marwan-ahmed/Work/RiscV/Design/shared_pkg.sv). This is the first file to read before making design or verification changes because it defines:

- ISA enums such as `opcode_t`, `alu_operation_t`, `csr_t`, `fpu_operation_t`
- register enums (`gpr_t`, `fpr_t`)
- trap encodings
- global parameters such as:
  - `FINAL_DATA_WIDTH = 32`
  - `FINAL_ADDR_WIDTH = 22`
  - `FINAL_PRECISION = SINGLE`
  - `CLK_PERIOD = 10`

## Supported Functionality

From the checked-in RTL and decoder definitions, the design appears to target:

- RV32 integer execution
- branch/jump handling
- load/store operations
- M-extension integer multiply/divide operations
- CSR/system instructions
- single-precision floating-point operations
- L1 instruction and data cache with configurable associativity

The floating-point path includes modules such as:

- [`Design/risc_fpu.sv`](/home/marwan-ahmed/Work/RiscV/Design/risc_fpu.sv)
- [`Design/flp_add_sub.sv`](/home/marwan-ahmed/Work/RiscV/Design/flp_add_sub.sv)
- [`Design/flp_mul.sv`](/home/marwan-ahmed/Work/RiscV/Design/flp_mul.sv)
- [`Design/flp_div.sv`](/home/marwan-ahmed/Work/RiscV/Design/flp_div.sv)
- [`Design/flp_sqrt.sv`](/home/marwan-ahmed/Work/RiscV/Design/flp_sqrt.sv)
- [`Design/fpu_decoder.sv`](/home/marwan-ahmed/Work/RiscV/Design/fpu_decoder.sv)

The execute stage is the main integration point for ALU, CSR, forwarding, branch decision, trap generation, and FPU handoff:

- [`Design/execute_stage.sv`](/home/marwan-ahmed/Work/RiscV/Design/execute_stage.sv)

## Fast File Map

If you need to work on a specific topic, start here:

- Core integration: [`Design/riscv_processor.sv`](/home/marwan-ahmed/Work/RiscV/Design/riscv_processor.sv)
- Global types/constants: [`Design/shared_pkg.sv`](/home/marwan-ahmed/Work/RiscV/Design/shared_pkg.sv)
- Fetch logic: [`Design/fetch_stage.sv`](/home/marwan-ahmed/Work/RiscV/Design/fetch_stage.sv)
- Decode/control path: [`Design/decode_stage.sv`](/home/marwan-ahmed/Work/RiscV/Design/decode_stage.sv), [`Design/opcode_decoder.sv`](/home/marwan-ahmed/Work/RiscV/Design/opcode_decoder.sv), [`Design/alu_decoder.sv`](/home/marwan-ahmed/Work/RiscV/Design/alu_decoder.sv), [`Design/fpu_decoder.sv`](/home/marwan-ahmed/Work/RiscV/Design/fpu_decoder.sv), [`Design/risc_control_unit.sv`](/home/marwan-ahmed/Work/RiscV/Design/risc_control_unit.sv)
- Execute path: [`Design/execute_stage.sv`](/home/marwan-ahmed/Work/RiscV/Design/execute_stage.sv), [`Design/risc_alu.sv`](/home/marwan-ahmed/Work/RiscV/Design/risc_alu.sv), [`Design/csr_file.sv`](/home/marwan-ahmed/Work/RiscV/Design/csr_file.sv)
- Memory/writeback: [`Design/memory_stage.sv`](/home/marwan-ahmed/Work/RiscV/Design/memory_stage.sv), [`Design/wb_stage.sv`](/home/marwan-ahmed/Work/RiscV/Design/wb_stage.sv), [`Design/risc_data_memory.sv`](/home/marwan-ahmed/Work/RiscV/Design/risc_data_memory.sv), [`Design/risc_instruction_memory.sv`](/home/marwan-ahmed/Work/RiscV/Design/risc_instruction_memory.sv)
- Hazard/forwarding: [`Design/hazard_unit.sv`](/home/marwan-ahmed/Work/RiscV/Design/hazard_unit.sv)
- Cache: [`Design/cache.sv`](/home/marwan-ahmed/Work/RiscV/Design/cache.sv) (L1 instruction/data cache)
- Integer register files: [`Design/risc_reg_file.sv`](/home/marwan-ahmed/Work/RiscV/Design/risc_reg_file.sv), [`Design/fp_reg_file.sv`](/home/marwan-ahmed/Work/RiscV/Design/fp_reg_file.sv)

## Verification Structure

`Verification/` is organized by block:

- `Fetch/`
- `Decode/`
- `Execute/`
- `Memory/`
- `WriteBack/`
- `Hazard/`
- `CSR/`
- `FPU/`
- `Risc/` for full-processor verification

Each block directory follows a repeated UVM structure:

- `*_interface.sv`
- `*_item_pkg.sv`
- `*_driver_pkg.sv`
- `*_monitor_pkg.sv`
- `*_scoreboard_pkg.sv`
- `*_seq_pkg.sv`
- `*_agent_pkg.sv`
- `*_env_pkg.sv`
- `*_test_pkg.sv`
- `*_top.sv`

Main simulation entry points:

- Full core: [`Verification/Risc/risc_top.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/risc_top.sv)
- Execute stage: [`Verification/Execute/execute_top.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Execute/execute_top.sv)
- Fetch stage: [`Verification/Fetch/fetch_top.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Fetch/fetch_top.sv)
- Memory stage: [`Verification/Memory/mem_top.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Memory/mem_top.sv)

The full-core UVM test binds internal wrappers into the DUT so individual pipeline stage activity can be observed from one top-level run:

- [`Verification/Risc/fetch_wr.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/fetch_wr.sv)
- [`Verification/Risc/decode_wr.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/decode_wr.sv)
- [`Verification/Risc/execute_wr.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/execute_wr.sv)
- [`Verification/Risc/memory_wr.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/memory_wr.sv)
- [`Verification/Risc/wb_wr.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/wb_wr.sv)
- [`Verification/Risc/hazard_wr.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/hazard_wr.sv)

## Python Program Generator

The random program generator is:

- [`Python/riscv_testcase_generator.py`](/home/marwan-ahmed/Work/RiscV/Python/riscv_testcase_generator.py)

It generates:

- assembly listings
- binary instruction files
- hex output
- `program_info.txt`, which the full-core UVM test uses to estimate when the program image ends

Related files:

- [`Python/README.md`](/home/marwan-ahmed/Work/RiscV/Python/README.md)
- [`Python/program_info.txt`](/home/marwan-ahmed/Work/RiscV/Python/program_info.txt)
- [`Python/assembly1.s`](/home/marwan-ahmed/Work/RiscV/Python/assembly1.s)
- [`Python/binary1.txt`](/home/marwan-ahmed/Work/RiscV/Python/binary1.txt)
- [`Python/hex1.v`](/home/marwan-ahmed/Work/RiscV/Python/hex1.v)

## Important Repo-Specific Notes

- There are many checked-in generated files under `Questa/`, `work/`, and `Syn/`. Be careful not to treat them as source of truth when editing functionality.
- The main source of truth for architectural intent is the RTL under `Design/` plus the scoreboards under `Verification/`.
- The repository currently contains hard-coded Windows paths for program metadata:
  - [`Verification/Risc/risc_test_pkg.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/risc_test_pkg.sv)
  - [`Python/riscv_testcase_generator.py`](/home/marwan-ahmed/Work/RiscV/Python/riscv_testcase_generator.py)
- If simulation/program loading is moved to another machine, those paths are likely to need adjustment first.
- `FINAL_ADDR_WIDTH = 22` implies a relatively large logical program/data address space in verification and memory models.

## Practical Workflow

When working on this repo later, the quickest path is usually:

1. Read [`Design/shared_pkg.sv`](/home/marwan-ahmed/Work/RiscV/Design/shared_pkg.sv).
2. Read the relevant stage RTL in `Design/`.
3. Read the matching scoreboard in `Verification/<Block>/`.
4. If debugging full-core behavior, start from [`Verification/Risc/risc_top.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/risc_top.sv) and [`Verification/Risc/risc_test_pkg.sv`](/home/marwan-ahmed/Work/RiscV/Verification/Risc/risc_test_pkg.sv).
5. If the failure depends on program contents, inspect the files in `Python/`.

## Suggested Next Improvements

If this repo will be used repeatedly, the highest-value cleanup items are:

- add a checked-in simulation compile/run script
- replace hard-coded absolute Windows paths with relative paths or plusargs
- separate generated artifacts from maintained source
- document memory initialization flow for instruction/data memories

