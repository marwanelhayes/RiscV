---
type: community
cohesion: 0.29
members: 7
---

# Hazard Verification

**Cohesion:** 0.29 - loosely connected
**Members:** 7 nodes

## Members
- [[hazard_driver_pkg.sv]] - code - Verification/Hazard/hazard_driver_pkg.sv
- [[hazard_interface.sv]] - code - Verification/Hazard/hazard_interface.sv
- [[hazard_item_pkg]] - code - Verification/Hazard/hazard_agent_pkg.sv
- [[hazard_monitor_pkg.sv]] - code - Verification/Hazard/hazard_monitor_pkg.sv
- [[hazard_scoreboard_pkg.sv]] - code - Verification/Hazard/hazard_scoreboard_pkg.sv
- [[hazard_seq_pkg.sv]] - code - Verification/Hazard/hazard_seq_pkg.sv
- [[hazard_subscriber_pkg.sv]] - code - Verification/Hazard/hazard_subscriber_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Hazard_Verification
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_UVM Verification Framework]]
- 3 edges to [[_COMMUNITY_Design Modules (RTL)]]
- 1 edge to [[_COMMUNITY_ExecuteFetch Verification]]

## Top bridge nodes
- [[hazard_scoreboard_pkg.sv]] - degree 3, connects to 2 communities
- [[hazard_seq_pkg.sv]] - degree 3, connects to 2 communities
- [[hazard_item_pkg]] - degree 7, connects to 1 community
- [[hazard_driver_pkg.sv]] - degree 2, connects to 1 community
- [[hazard_interface.sv]] - degree 2, connects to 1 community