---
type: community
cohesion: 0.22
members: 9
---

# Fetch/Execute Verification

**Cohesion:** 0.22 - loosely connected
**Members:** 9 nodes

## Members
- [[execute_env_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[execute_test_pkg.sv]] - code - Verification/Execute/execute_test_pkg.sv
- [[fetch_agent_pkg.sv]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_config_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[fetch_driver_pkg]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_env_pkg.sv]] - code - Verification/Fetch/fetch_env_pkg.sv
- [[fetch_monitor_pkg]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_test_pkg.sv]] - code - Verification/Fetch/fetch_test_pkg.sv
- [[risc_test_pkg.sv]] - code - Verification/Risc/risc_test_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Fetch/Execute_Verification
SORT file.name ASC
```

## Connections to other communities
- 2 edges to [[_COMMUNITY_CSR & Decode Verification]]
- 1 edge to [[_COMMUNITY_Memory Verification Packages]]

## Top bridge nodes
- [[fetch_agent_pkg.sv]] - degree 5, connects to 1 community
- [[risc_test_pkg.sv]] - degree 3, connects to 1 community