---
type: community
cohesion: 0.29
members: 7
---

# Fetch Verification

**Cohesion:** 0.29 - loosely connected
**Members:** 7 nodes

## Members
- [[fetch_driver_pkg.sv]] - code - Verification/Fetch/fetch_driver_pkg.sv
- [[fetch_interface.sv]] - code - Verification/Fetch/fetch_interface.sv
- [[fetch_item_pkg]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_monitor_pkg.sv]] - code - Verification/Fetch/fetch_monitor_pkg.sv
- [[fetch_scoreboard_pkg.sv]] - code - Verification/Fetch/fetch_scoreboard_pkg.sv
- [[fetch_seq_pkg.sv]] - code - Verification/Fetch/fetch_seq_pkg.sv
- [[fetch_subscriber_pkg.sv]] - code - Verification/Fetch/fetch_subscriber_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Fetch_Verification
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_UVM Verification Framework]]
- 3 edges to [[_COMMUNITY_Design Modules (RTL)]]
- 1 edge to [[_COMMUNITY_ExecuteFetch Verification]]

## Top bridge nodes
- [[fetch_scoreboard_pkg.sv]] - degree 3, connects to 2 communities
- [[fetch_seq_pkg.sv]] - degree 3, connects to 2 communities
- [[fetch_item_pkg]] - degree 7, connects to 1 community
- [[fetch_driver_pkg.sv]] - degree 2, connects to 1 community
- [[fetch_interface.sv]] - degree 2, connects to 1 community