---
type: community
cohesion: 0.07
members: 30
---

# Execute/Fetch Verification

**Cohesion:** 0.07 - loosely connected
**Members:** 30 nodes

## Members
- [[execute_agent_pkg.sv]] - code - Verification/Execute/execute_agent_pkg.sv
- [[execute_config_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[execute_driver_pkg]] - code - Verification/Execute/execute_agent_pkg.sv
- [[execute_env_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[execute_monitor_pkg]] - code - Verification/Execute/execute_agent_pkg.sv
- [[execute_seq_pkg]] - code - Verification/Execute/execute_test_pkg.sv
- [[execute_test_pkg.sv]] - code - Verification/Execute/execute_test_pkg.sv
- [[fetch_agent_pkg]] - code - Verification/Fetch/fetch_env_pkg.sv
- [[fetch_agent_pkg.sv]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_config_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[fetch_driver_pkg]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_env_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[fetch_env_pkg.sv]] - code - Verification/Fetch/fetch_env_pkg.sv
- [[fetch_monitor_pkg]] - code - Verification/Fetch/fetch_agent_pkg.sv
- [[fetch_scoreboard_pkg]] - code - Verification/Fetch/fetch_env_pkg.sv
- [[fetch_seq_pkg]] - code - Verification/Fetch/fetch_test_pkg.sv
- [[fetch_subscriber_pkg]] - code - Verification/Fetch/fetch_env_pkg.sv
- [[fetch_test_pkg.sv]] - code - Verification/Fetch/fetch_test_pkg.sv
- [[hazard_agent_pkg]] - code - Verification/Hazard/hazard_env_pkg.sv
- [[hazard_agent_pkg.sv]] - code - Verification/Hazard/hazard_agent_pkg.sv
- [[hazard_config_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[hazard_driver_pkg]] - code - Verification/Hazard/hazard_agent_pkg.sv
- [[hazard_env_pkg]] - code - Verification/Risc/risc_test_pkg.sv
- [[hazard_env_pkg.sv]] - code - Verification/Hazard/hazard_env_pkg.sv
- [[hazard_monitor_pkg]] - code - Verification/Hazard/hazard_agent_pkg.sv
- [[hazard_scoreboard_pkg]] - code - Verification/Hazard/hazard_env_pkg.sv
- [[hazard_seq_pkg]] - code - Verification/Hazard/hazard_test_pkg.sv
- [[hazard_subscriber_pkg]] - code - Verification/Hazard/hazard_env_pkg.sv
- [[hazard_test_pkg.sv]] - code - Verification/Hazard/hazard_test_pkg.sv
- [[risc_test_pkg.sv]] - code - Verification/Risc/risc_test_pkg.sv

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Execute/Fetch_Verification
SORT file.name ASC
```

## Connections to other communities
- 9 edges to [[_COMMUNITY_UVM Verification Framework]]
- 2 edges to [[_COMMUNITY_Memory Verification Packages]]
- 2 edges to [[_COMMUNITY_Decode Verification Packages]]
- 2 edges to [[_COMMUNITY_Writeback Verification Packages]]
- 1 edge to [[_COMMUNITY_Design Modules (RTL)]]
- 1 edge to [[_COMMUNITY_Hazard Verification]]
- 1 edge to [[_COMMUNITY_Execute Verification]]
- 1 edge to [[_COMMUNITY_CSR Verification Packages]]
- 1 edge to [[_COMMUNITY_Fetch Verification]]

## Top bridge nodes
- [[risc_test_pkg.sv]] - degree 14, connects to 5 communities
- [[execute_agent_pkg.sv]] - degree 5, connects to 2 communities
- [[fetch_agent_pkg.sv]] - degree 5, connects to 2 communities
- [[hazard_agent_pkg.sv]] - degree 5, connects to 2 communities
- [[fetch_env_pkg.sv]] - degree 5, connects to 1 community