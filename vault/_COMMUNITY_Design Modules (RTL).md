---
type: community
cohesion: 0.07
members: 27
---

# Design Modules (RTL)

**Cohesion:** 0.07 - loosely connected
**Members:** 27 nodes

## Members
- [[alu_decoder.sv]] - code - Design/alu_decoder.sv
- [[csr_file.sv]] - code - Design/csr_file.sv
- [[csr_wr.sv]] - code - Verification/Risc/csr_wr.sv
- [[decode_stage.sv]] - code - Design/decode_stage.sv
- [[execute_stage.sv]] - code - Design/execute_stage.sv
- [[execute_wr.sv]] - code - Verification/Risc/execute_wr.sv
- [[flp_add_sub.sv]] - code - Design/flp_add_sub.sv
- [[flp_div.sv]] - code - Design/flp_div.sv
- [[flp_mul.sv]] - code - Design/flp_mul.sv
- [[flp_sqrt.sv]] - code - Design/flp_sqrt.sv
- [[fp_reg_file.sv]] - code - Design/fp_reg_file.sv
- [[fpu_decoder.sv]] - code - Design/fpu_decoder.sv
- [[hazard_unit.sv]] - code - Design/hazard_unit.sv
- [[hazard_wr.sv]] - code - Verification/Risc/hazard_wr.sv
- [[memory_stage.sv]] - code - Design/memory_stage.sv
- [[opcode_decoder.sv]] - code - Design/opcode_decoder.sv
- [[risc_alu.sv]] - code - Design/risc_alu.sv
- [[risc_control_unit.sv]] - code - Design/risc_control_unit.sv
- [[risc_data_memory.sv]] - code - Design/risc_data_memory.sv
- [[risc_fpu.sv]] - code - Design/risc_fpu.sv
- [[risc_interface.sv]] - code - Verification/Risc/risc_interface.sv
- [[risc_mem.sv]] - code - Design/risc_mem.sv
- [[risc_reg_file.sv]] - code - Design/risc_reg_file.sv
- [[riscv_processor.sv]] - code - Design/riscv_processor.sv
- [[shared_pkg]] - code - Verification/WriteBack/writeback_scoreboard_pkg.sv
- [[wallace_tree.sv]] - code - Design/wallace_tree.sv
- [[wb_stage.sv]] - code - Design/wb_stage.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Design_Modules_(RTL)
SORT file.name ASC
```

## Connections to other communities
- 16 edges to [[_COMMUNITY_UVM Verification Framework]]
- 3 edges to [[_COMMUNITY_Hazard Verification]]
- 3 edges to [[_COMMUNITY_Memory Verification Packages]]
- 3 edges to [[_COMMUNITY_Execute Verification]]
- 3 edges to [[_COMMUNITY_CSR Verification Packages]]
- 3 edges to [[_COMMUNITY_Decode Verification Packages]]
- 3 edges to [[_COMMUNITY_FPU Verification]]
- 3 edges to [[_COMMUNITY_Fetch Verification]]
- 3 edges to [[_COMMUNITY_Writeback Verification Packages]]
- 1 edge to [[_COMMUNITY_Hazard Verification Top]]
- 1 edge to [[_COMMUNITY_Memory Verification Top]]
- 1 edge to [[_COMMUNITY_Execute Verification Top]]
- 1 edge to [[_COMMUNITY_CSR Verification Top]]
- 1 edge to [[_COMMUNITY_Decode Verification Top]]
- 1 edge to [[_COMMUNITY_FPU Verification Top]]
- 1 edge to [[_COMMUNITY_Fetch Verification Top]]
- 1 edge to [[_COMMUNITY_RISC Verification Top]]
- 1 edge to [[_COMMUNITY_ExecuteFetch Verification]]
- 1 edge to [[_COMMUNITY_Writeback Verification Top]]

## Top bridge nodes
- [[shared_pkg]] - degree 73, connects to 19 communities
- [[csr_wr.sv]] - degree 2, connects to 1 community
- [[execute_wr.sv]] - degree 2, connects to 1 community
- [[hazard_wr.sv]] - degree 2, connects to 1 community