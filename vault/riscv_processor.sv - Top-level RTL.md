---
source_file: "Design/riscv_processor.sv"
type: "code"
community: "Decode/Execute/FPU Design"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Decode/Execute/FPU_Design
---

# riscv_processor.sv - Top-level RTL

## Connections
- [[decode_stage - Instruction decode]] - `instantiates` [EXTRACTED]
- [[execute_stage - Execute stage integration]] - `instantiates` [EXTRACTED]
- [[fetch_stage - Instruction fetch]] - `instantiates` [EXTRACTED]
- [[fp_reg_file - Floating point register file]] - `instantiates` [EXTRACTED]
- [[hazard_unit - Hazard detection]] - `instantiates` [EXTRACTED]
- [[memory_stage - Memory access]] - `instantiates` [EXTRACTED]
- [[risc_reg_file - Integer register file]] - `instantiates` [EXTRACTED]
- [[risc_top.sv - Full processor verification]] - `verifies` [EXTRACTED]
- [[shared_pkg.sv - ISA and register enums]] - `references` [EXTRACTED]
- [[wb_stage - Writeback]] - `instantiates` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Decode/Execute/FPU_Design