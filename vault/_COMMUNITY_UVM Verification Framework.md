---
type: community
cohesion: 0.09
members: 22
---

# UVM Verification Framework

**Cohesion:** 0.09 - loosely connected
**Members:** 22 nodes

## Members
- [[csr_config_pkg.sv]] - code - Verification/CSR/csr_config_pkg.sv
- [[csr_item_pkg.sv]] - code - Verification/CSR/csr_item_pkg.sv
- [[decode_config_pkg.sv]] - code - Verification/Decode/decode_config_pkg.sv
- [[decode_item_pkg.sv]] - code - Verification/Decode/decode_item_pkg.sv
- [[decode_wr.sv]] - code - Verification/Risc/decode_wr.sv
- [[execute_config_pkg.sv]] - code - Verification/Execute/execute_config_pkg.sv
- [[execute_item_pkg.sv]] - code - Verification/Execute/execute_item_pkg.sv
- [[fetch_config_pkg.sv]] - code - Verification/Fetch/fetch_config_pkg.sv
- [[fetch_item_pkg.sv]] - code - Verification/Fetch/fetch_item_pkg.sv
- [[fetch_wr.sv]] - code - Verification/Risc/fetch_wr.sv
- [[flp_config_pkg.sv]] - code - Verification/FPU/flp_config_pkg.sv
- [[flp_item_pkg.sv]] - code - Verification/FPU/flp_item_pkg.sv
- [[flp_wr.sv]] - code - Verification/Risc/flp_wr.sv
- [[hazard_config_pkg.sv]] - code - Verification/Hazard/hazard_config_pkg.sv
- [[hazard_item_pkg.sv]] - code - Verification/Hazard/hazard_item_pkg.sv
- [[mem_config_pkg.sv]] - code - Verification/Memory/mem_config_pkg.sv
- [[mem_item_pkg.sv]] - code - Verification/Memory/mem_item_pkg.sv
- [[memory_wr.sv]] - code - Verification/Risc/memory_wr.sv
- [[uvm_pkg]] - code - Verification/WriteBack/writeback_scoreboard_pkg.sv
- [[wb_wr.sv]] - code - Verification/Risc/wb_wr.sv
- [[writeback_config_pkg.sv]] - code - Verification/WriteBack/writeback_config_pkg.sv
- [[writeback_item_pkg.sv]] - code - Verification/WriteBack/writeback_item_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/UVM_Verification_Framework
SORT file.name ASC
```

## Connections to other communities
- 16 edges to [[_COMMUNITY_Design Modules (RTL)]]
- 12 edges to [[_COMMUNITY_CSR Verification Packages]]
- 9 edges to [[_COMMUNITY_ExecuteFetch Verification]]
- 8 edges to [[_COMMUNITY_Memory Verification Packages]]
- 8 edges to [[_COMMUNITY_Decode Verification Packages]]
- 8 edges to [[_COMMUNITY_Writeback Verification Packages]]
- 5 edges to [[_COMMUNITY_Hazard Verification]]
- 5 edges to [[_COMMUNITY_Execute Verification]]
- 5 edges to [[_COMMUNITY_FPU Verification]]
- 5 edges to [[_COMMUNITY_Fetch Verification]]
- 1 edge to [[_COMMUNITY_Hazard Verification Top]]
- 1 edge to [[_COMMUNITY_Memory Verification Top]]
- 1 edge to [[_COMMUNITY_Execute Verification Top]]
- 1 edge to [[_COMMUNITY_CSR Verification Top]]
- 1 edge to [[_COMMUNITY_Decode Verification Top]]
- 1 edge to [[_COMMUNITY_FPU Verification Top]]
- 1 edge to [[_COMMUNITY_Fetch Verification Top]]
- 1 edge to [[_COMMUNITY_RISC Verification Top]]
- 1 edge to [[_COMMUNITY_Writeback Verification Top]]

## Top bridge nodes
- [[uvm_pkg]] - degree 98, connects to 19 communities
- [[csr_item_pkg.sv]] - degree 2, connects to 1 community
- [[decode_item_pkg.sv]] - degree 2, connects to 1 community
- [[execute_item_pkg.sv]] - degree 2, connects to 1 community
- [[fetch_item_pkg.sv]] - degree 2, connects to 1 community