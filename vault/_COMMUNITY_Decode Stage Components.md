---
type: community
cohesion: 0.25
members: 8
---

# Decode Stage Components

**Cohesion:** 0.25 - loosely connected
**Members:** 8 nodes

## Members
- [[alu_decoder - ALU decoder]] - code - Design/alu_decoder.sv
- [[decode_stage - Instruction decode]] - code - Design/decode_stage.sv
- [[fp_reg_file - Floating point register file]] - code - Design/decode_stage.sv
- [[fpu_decoder - FPU decoder]] - code - Design/decode_stage.sv
- [[opcode_decoder - Opcode decoder]] - code - Design/decode_stage.sv
- [[risc_control_unit - Control unit]] - code - Design/risc_control_unit.sv
- [[risc_reg_file - Integer register file]] - code - Design/decode_stage.sv
- [[riscv_processor.sv - Top-level RTL]] - code - Design/riscv_processor.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Decode_Stage_Components
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_CSR & Decode Verification]]

## Top bridge nodes
- [[riscv_processor.sv - Top-level RTL]] - degree 2, connects to 1 community