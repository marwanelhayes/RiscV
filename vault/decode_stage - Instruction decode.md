---
source_file: "Design/decode_stage.sv"
type: "code"
community: "Decode/Execute/FPU Design"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Decode/Execute/FPU_Design
---

# decode_stage - Instruction decode

## Connections
- [[alu_decoder - ALU decoder]] - `instantiates` [EXTRACTED]
- [[fp_reg_file - Floating point register file]] - `references` [EXTRACTED]
- [[fpu_decoder - FPU decoder]] - `instantiates` [EXTRACTED]
- [[opcode_decoder - Opcode decoder]] - `instantiates` [EXTRACTED]
- [[risc_control_unit - Control unit]] - `instantiates` [EXTRACTED]
- [[risc_reg_file - Integer register file]] - `references` [EXTRACTED]
- [[riscv_processor.sv - Top-level RTL]] - `instantiates` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Decode/Execute/FPU_Design