---
type: community
cohesion: 0.14
members: 20
---

# CSR & Decode Verification

**Cohesion:** 0.14 - loosely connected
**Members:** 20 nodes

## Members
- [[alu_decoder.sv]] - code - Design/alu_decoder.sv
- [[csr_file.sv]] - code - Design/csr_file.sv
- [[csr_item_pkg.sv]] - code - Verification/CSR/csr_item_pkg.sv
- [[csr_wr.sv]] - code - Verification/Risc/csr_wr.sv
- [[decode_wr.sv]] - code - Verification/Risc/decode_wr.sv
- [[execute_item_pkg]] - code - Verification/Execute/execute_monitor_pkg.sv
- [[execute_monitor_pkg.sv]] - code - Verification/Execute/execute_monitor_pkg.sv
- [[fetch_item_pkg]] - code - Verification/Fetch/fetch_seq_pkg.sv
- [[fetch_seq_pkg.sv]] - code - Verification/Fetch/fetch_seq_pkg.sv
- [[fetch_subscriber_pkg.sv]] - code - Verification/Fetch/fetch_subscriber_pkg.sv
- [[shared_pkg]] - code - Verification/Risc/decode_wr.sv
- [[uvm_pkg]] - code - Verification/Execute/execute_monitor_pkg.sv
- [[wb_wr.sv]] - code - Verification/Risc/wb_wr.sv
- [[writeback_agent_pkg.sv]] - code - Verification/WriteBack/writeback_agent_pkg.sv
- [[writeback_config_pkg]] - code - Verification/WriteBack/writeback_agent_pkg.sv
- [[writeback_driver_pkg]] - code - Verification/WriteBack/writeback_agent_pkg.sv
- [[writeback_item_pkg]] - code - Verification/WriteBack/writeback_item_pkg.sv
- [[writeback_item_pkg.sv]] - code - Verification/WriteBack/writeback_item_pkg.sv
- [[writeback_monitor_pkg]] - code - Verification/WriteBack/writeback_agent_pkg.sv
- [[writeback_subscriber_pkg.sv]] - code - Verification/WriteBack/writeback_subscriber_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/CSR_&_Decode_Verification
SORT file.name ASC
```

## Connections to other communities
- 2 edges to [[_COMMUNITY_Memory Verification Packages]]
- 2 edges to [[_COMMUNITY_FetchExecute Verification]]
- 1 edge to [[_COMMUNITY_Decode Stage Components]]

## Top bridge nodes
- [[uvm_pkg]] - degree 13, connects to 2 communities
- [[shared_pkg]] - degree 9, connects to 1 community
- [[fetch_item_pkg]] - degree 3, connects to 1 community