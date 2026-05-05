---
type: community
cohesion: 0.08
members: 30
---

# Decode/Execute/FPU Design

**Cohesion:** 0.08 - loosely connected
**Members:** 30 nodes

## Members
- [[Python Generator README]] - document - Python/README.md
- [[alu_decoder - ALU decoder]] - code - Design/alu_decoder.sv
- [[binary1.txt - Generated instructions]] - document - Python/binary1.txt
- [[csr_file - ControlStatus Registers]] - code - Design/csr_file.sv
- [[decode_stage - Instruction decode]] - code - Design/decode_stage.sv
- [[execute_stage - Execute stage integration]] - code - Design/execute_stage.sv
- [[execute_top.sv - Execute stage verification]] - code - Verification/Execute/execute_top.sv
- [[fetch_stage - Instruction fetch]] - code - Design/fetch_stage.sv
- [[fetch_top.sv - Fetch stage verification]] - code - Verification/Fetch/fetch_top.sv
- [[flp_add_sub - FPU AddSub]] - code - Design/flp_add_sub.sv
- [[flp_div - FPU Divide]] - code - Design/flp_div.sv
- [[flp_mul - FPU Multiply]] - code - Design/flp_mul.sv
- [[flp_sqrt - FPU Square Root]] - code - Design/flp_sqrt.sv
- [[fp_reg_file - Floating point register file]] - code - Design/fp_reg_file.sv
- [[fpu_decoder - FPU decoder]] - code - Design/fpu_decoder.sv
- [[hazard_unit - Hazard detection]] - code - Design/hazard_unit.sv
- [[mem_top.sv - Memory stage verification]] - code - Verification/Memory/mem_top.sv
- [[memory_stage - Memory access]] - code - Design/memory_stage.sv
- [[opcode_decoder - Opcode decoder]] - code - Design/opcode_decoder.sv
- [[program_info.txt - Program metadata]] - document - Python/program_info.txt
- [[risc_alu - ALU]] - code - Design/risc_alu.sv
- [[risc_control_unit - Control unit]] - code - Design/risc_control_unit.sv
- [[risc_data_memory - Data memory]] - code - Design/risc_data_memory.sv
- [[risc_fpu - Floating Point Unit]] - code - Design/risc_fpu.sv
- [[risc_instruction_memory - Instruction memory]] - code - Design/risc_instruction_memory.sv
- [[risc_reg_file - Integer register file]] - code - Design/risc_reg_file.sv
- [[risc_top.sv - Full processor verification]] - code - Verification/Risc/risc_top.sv
- [[riscv_processor.sv - Top-level RTL]] - code - Design/riscv_processor.sv
- [[riscv_testcase_generator.py_1]] - code - Python/riscv_testcase_generator.py
- [[wb_stage - Writeback]] - code - Design/wb_stage.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Decode/Execute/FPU_Design
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_ISA Definitions & Parameters]]

## Top bridge nodes
- [[riscv_processor.sv - Top-level RTL]] - degree 10, connects to 1 community