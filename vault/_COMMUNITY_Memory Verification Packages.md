---
type: community
cohesion: 0.11
members: 18
---

# Memory Verification Packages

**Cohesion:** 0.11 - loosely connected
**Members:** 18 nodes

## Members
- [[mem_agent_pkg]] - code - Verification/Memory/mem_env_pkg.sv
- [[mem_agent_pkg.sv]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_config_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[mem_driver_pkg]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_driver_pkg.sv]] - code - Verification/Memory/mem_driver_pkg.sv
- [[mem_env_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[mem_env_pkg.sv]] - code - Verification/Memory/mem_env_pkg.sv
- [[mem_interface.sv]] - code - Verification/Memory/mem_interface.sv
- [[mem_item_pkg]] - code - Verification/Memory/mem_driver_pkg.sv
- [[mem_monitor_pkg]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_monitor_pkg.sv]] - code - Verification/Memory/mem_monitor_pkg.sv
- [[mem_scoreboard_pkg]] - code - Verification/Memory/mem_env_pkg.sv
- [[mem_scoreboard_pkg.sv]] - code - Verification/Memory/mem_scoreboard_pkg.sv
- [[mem_seq_pkg]] - code - Verification/Memory/mem_test_pkg.sv
- [[mem_seq_pkg.sv]] - code - Verification/Memory/mem_seq_pkg.sv
- [[mem_subscriber_pkg]] - code - Verification/Memory/mem_env_pkg.sv
- [[mem_subscriber_pkg.sv]] - code - Verification/Memory/mem_subscriber_pkg.sv
- [[mem_test_pkg.sv]] - code - Verification/Memory/mem_test_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Memory_Verification_Packages
SORT file.name ASC
```

## Connections to other communities
- 8 edges to [[_COMMUNITY_UVM Verification Framework]]
- 3 edges to [[_COMMUNITY_Design Modules (RTL)]]
- 2 edges to [[_COMMUNITY_ExecuteFetch Verification]]

## Top bridge nodes
- [[mem_scoreboard_pkg.sv]] - degree 3, connects to 2 communities
- [[mem_seq_pkg.sv]] - degree 3, connects to 2 communities
- [[mem_agent_pkg.sv]] - degree 5, connects to 1 community
- [[mem_env_pkg.sv]] - degree 5, connects to 1 community
- [[mem_config_pkg]] - degree 4, connects to 1 community