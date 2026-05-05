---
type: community
cohesion: 0.29
members: 7
---

# Execute Verification

**Cohesion:** 0.29 - loosely connected
**Members:** 7 nodes

## Members
- [[execute_driver_pkg.sv]] - code - Verification/Execute/execute_driver_pkg.sv
- [[execute_interface.sv]] - code - Verification/Execute/execute_interface.sv
- [[execute_item_pkg]] - code - Verification/Execute/execute_scoreboard_pkg.sv
- [[execute_monitor_pkg.sv]] - code - Verification/Execute/execute_monitor_pkg.sv
- [[execute_scoreboard_pkg.sv]] - code - Verification/Execute/execute_scoreboard_pkg.sv
- [[execute_seq_pkg.sv]] - code - Verification/Execute/execute_seq_pkg.sv
- [[execute_subscriber_pkg.sv]] - code - Verification/Execute/execute_subscriber_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Execute_Verification
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_UVM Verification Framework]]
- 3 edges to [[_COMMUNITY_Design Modules (RTL)]]
- 1 edge to [[_COMMUNITY_ExecuteFetch Verification]]

## Top bridge nodes
- [[execute_scoreboard_pkg.sv]] - degree 3, connects to 2 communities
- [[execute_seq_pkg.sv]] - degree 3, connects to 2 communities
- [[execute_item_pkg]] - degree 7, connects to 1 community
- [[execute_driver_pkg.sv]] - degree 2, connects to 1 community
- [[execute_interface.sv]] - degree 2, connects to 1 community