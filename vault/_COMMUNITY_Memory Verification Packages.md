---
type: community
cohesion: 0.22
members: 9
---

# Memory Verification Packages

**Cohesion:** 0.22 - loosely connected
**Members:** 9 nodes

## Members
- [[mem_agent_pkg.sv]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_config_pkg]] - code - Verification/Memory/mem_test_pkg.sv
- [[mem_driver_pkg]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_env_pkg]] - code - Verification/Memory/mem_test_pkg.sv
- [[mem_env_pkg.sv]] - code - Verification/Memory/mem_env_pkg.sv
- [[mem_item_pkg]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_monitor_pkg]] - code - Verification/Memory/mem_agent_pkg.sv
- [[mem_seq_pkg]] - code - Verification/Memory/mem_test_pkg.sv
- [[mem_test_pkg.sv]] - code - Verification/Memory/mem_test_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Memory_Verification_Packages
SORT file.name ASC
```

## Connections to other communities
- 2 edges to [[_COMMUNITY_CSR & Decode Verification]]
- 1 edge to [[_COMMUNITY_FetchExecute Verification]]

## Top bridge nodes
- [[mem_agent_pkg.sv]] - degree 5, connects to 1 community
- [[mem_config_pkg]] - degree 4, connects to 1 community
- [[mem_test_pkg.sv]] - degree 4, connects to 1 community