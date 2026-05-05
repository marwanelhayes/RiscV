---
type: community
cohesion: 0.29
members: 7
---

# FPU Verification

**Cohesion:** 0.29 - loosely connected
**Members:** 7 nodes

## Members
- [[flp_driver_pkg.sv]] - code - Verification/FPU/flp_driver_pkg.sv
- [[flp_interface.sv]] - code - Verification/FPU/flp_interface.sv
- [[flp_item_pkg]] - code - Verification/FPU/flp_interface.sv
- [[flp_monitor_pkg.sv]] - code - Verification/FPU/flp_monitor_pkg.sv
- [[flp_scoreboard_pkg.sv]] - code - Verification/FPU/flp_scoreboard_pkg.sv
- [[flp_seq_pkg.sv]] - code - Verification/FPU/flp_seq_pkg.sv
- [[flp_subscriber_pkg.sv]] - code - Verification/FPU/flp_subscriber_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/FPU_Verification
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_UVM Verification Framework]]
- 3 edges to [[_COMMUNITY_Design Modules (RTL)]]
- 1 edge to [[_COMMUNITY_CSR Verification Packages]]

## Top bridge nodes
- [[flp_scoreboard_pkg.sv]] - degree 3, connects to 2 communities
- [[flp_seq_pkg.sv]] - degree 3, connects to 2 communities
- [[flp_item_pkg]] - degree 7, connects to 1 community
- [[flp_driver_pkg.sv]] - degree 2, connects to 1 community
- [[flp_interface.sv]] - degree 2, connects to 1 community