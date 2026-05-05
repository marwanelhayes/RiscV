---
source_file: "Design/execute_stage.sv"
type: "code"
community: "Decode/Execute/FPU Design"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Decode/Execute/FPU_Design
---

# execute_stage - Execute stage integration

## Connections
- [[csr_file - ControlStatus Registers]] - `instantiates` [EXTRACTED]
- [[execute_top.sv - Execute stage verification]] - `verifies` [EXTRACTED]
- [[hazard_unit - Hazard detection]] - `semantically_similar_to` [INFERRED]
- [[risc_alu - ALU]] - `instantiates` [EXTRACTED]
- [[risc_fpu - Floating Point Unit]] - `instantiates` [EXTRACTED]
- [[riscv_processor.sv - Top-level RTL]] - `instantiates` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Decode/Execute/FPU_Design