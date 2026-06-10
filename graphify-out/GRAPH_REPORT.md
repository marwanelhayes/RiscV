# Graph Report - /home/marwan-ahmed/Work/RiscV (Design+Verification)  (2026-05-26)

## Corpus Check
- 143 files · ~51,353 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 227 nodes · 341 edges · 20 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Design RTL Modules|Design RTL Modules]]
- [[_COMMUNITY_Verification Config Packages|Verification Config Packages]]
- [[_COMMUNITY_ExecuteHazard Env Packages|Execute/Hazard Env Packages]]
- [[_COMMUNITY_CSR Verification|CSR Verification]]
- [[_COMMUNITY_Fetch Verification Components|Fetch Verification Components]]
- [[_COMMUNITY_Decode Verification Components|Decode Verification Components]]
- [[_COMMUNITY_Hazard Stage Verification|Hazard Stage Verification]]
- [[_COMMUNITY_Memory Stage Verification|Memory Stage Verification]]
- [[_COMMUNITY_Execute Stage Verification|Execute Stage Verification]]
- [[_COMMUNITY_CSR Stage Verification|CSR Stage Verification]]
- [[_COMMUNITY_Writeback Stage Verification|Writeback Stage Verification]]
- [[_COMMUNITY_Fetch Stage Sources|Fetch Stage Sources]]
- [[_COMMUNITY_CSR Defs|CSR Defs]]
- [[_COMMUNITY_LZC Component|LZC Component]]
- [[_COMMUNITY_Non-Restoring Divider|Non-Restoring Divider]]
- [[_COMMUNITY_Shared Pkg|Shared Pkg]]
- [[_COMMUNITY_PC Adder|PC Adder]]
- [[_COMMUNITY_Mux4 Component|Mux4 Component]]
- [[_COMMUNITY_Mux3 Component|Mux3 Component]]
- [[_COMMUNITY_Mux2 Component|Mux2 Component]]

## God Nodes (most connected - your core abstractions)
1. `uvm_pkg` - 99 edges
2. `shared_pkg` - 79 edges
3. `fetch_item_pkg` - 8 edges
4. `hazard_item_pkg` - 7 edges
5. `mem_item_pkg` - 7 edges
6. `execute_item_pkg` - 7 edges
7. `csr_item_pkg` - 7 edges
8. `decode_item_pkg` - 7 edges
9. `flp_item_pkg` - 7 edges
10. `writeback_item_pkg` - 7 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

### Community 0 - "Design RTL Modules"
Cohesion: 0.04
Nodes (10): csr_test_pkg, decode_test_pkg, execute_test_pkg, fetch_test_pkg, flp_test_pkg, hazard_test_pkg, mem_test_pkg, risc_test_pkg (+2 more)

### Community 1 - "Verification Config Packages"
Cohesion: 0.08
Nodes (3): decode_item_pkg, flp_item_pkg, uvm_pkg

### Community 2 - "Execute/Hazard Env Packages"
Cohesion: 0.08
Nodes (21): execute_config_pkg, execute_env_pkg, execute_seq_pkg, hazard_agent_pkg, hazard_config_pkg, hazard_env_pkg, hazard_scoreboard_pkg, hazard_seq_pkg (+13 more)

### Community 3 - "CSR Verification"
Cohesion: 0.09
Nodes (17): csr_agent_pkg, csr_config_pkg, csr_env_pkg, csr_scoreboard_pkg, csr_seq_pkg, csr_subscriber_pkg, execute_agent_pkg, execute_scoreboard_pkg (+9 more)

### Community 4 - "Fetch Verification Components"
Cohesion: 0.17
Nodes (9): fetch_agent_pkg, fetch_config_pkg, fetch_driver_pkg, fetch_env_pkg, fetch_monitor_pkg, fetch_predictor_pkg, fetch_scoreboard_pkg, fetch_seq_pkg (+1 more)

### Community 5 - "Decode Verification Components"
Cohesion: 0.18
Nodes (8): decode_agent_pkg, decode_config_pkg, decode_driver_pkg, decode_env_pkg, decode_monitor_pkg, decode_scoreboard_pkg, decode_seq_pkg, decode_subscriber_pkg

### Community 6 - "Hazard Stage Verification"
Cohesion: 0.2
Nodes (3): hazard_driver_pkg, hazard_item_pkg, hazard_monitor_pkg

### Community 7 - "Memory Stage Verification"
Cohesion: 0.2
Nodes (3): mem_driver_pkg, mem_item_pkg, mem_monitor_pkg

### Community 8 - "Execute Stage Verification"
Cohesion: 0.2
Nodes (3): execute_driver_pkg, execute_item_pkg, execute_monitor_pkg

### Community 9 - "CSR Stage Verification"
Cohesion: 0.2
Nodes (3): csr_driver_pkg, csr_item_pkg, csr_monitor_pkg

### Community 10 - "Writeback Stage Verification"
Cohesion: 0.2
Nodes (3): writeback_driver_pkg, writeback_item_pkg, writeback_monitor_pkg

### Community 11 - "Fetch Stage Sources"
Cohesion: 0.25
Nodes (1): fetch_item_pkg

### Community 12 - "CSR Defs"
Cohesion: 1.0
Nodes (0): 

### Community 13 - "LZC Component"
Cohesion: 1.0
Nodes (0): 

### Community 14 - "Non-Restoring Divider"
Cohesion: 1.0
Nodes (0): 

### Community 15 - "Shared Pkg"
Cohesion: 1.0
Nodes (0): 

### Community 16 - "PC Adder"
Cohesion: 1.0
Nodes (0): 

### Community 17 - "Mux4 Component"
Cohesion: 1.0
Nodes (0): 

### Community 18 - "Mux3 Component"
Cohesion: 1.0
Nodes (0): 

### Community 19 - "Mux2 Component"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **58 isolated node(s):** `hazard_test_pkg`, `hazard_agent_pkg`, `hazard_scoreboard_pkg`, `hazard_subscriber_pkg`, `hazard_seq_pkg` (+53 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `CSR Defs`** (1 nodes): `csr_defs.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `LZC Component`** (1 nodes): `lzc_wr.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Non-Restoring Divider`** (1 nodes): `non_restoring_divider.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Shared Pkg`** (1 nodes): `shared_pkg.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `PC Adder`** (1 nodes): `pc_adder.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux4 Component`** (1 nodes): `risc_mux4.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux3 Component`** (1 nodes): `risc_mux3.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux2 Component`** (1 nodes): `risc_mux2.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `uvm_pkg` connect `Verification Config Packages` to `Design RTL Modules`, `Execute/Hazard Env Packages`, `CSR Verification`, `Fetch Verification Components`, `Decode Verification Components`, `Hazard Stage Verification`, `Memory Stage Verification`, `Execute Stage Verification`, `CSR Stage Verification`, `Writeback Stage Verification`, `Fetch Stage Sources`?**
  _High betweenness centrality (0.718) - this node is a cross-community bridge._
- **Why does `shared_pkg` connect `Design RTL Modules` to `Verification Config Packages`, `Execute/Hazard Env Packages`, `Hazard Stage Verification`, `Memory Stage Verification`, `Execute Stage Verification`, `CSR Stage Verification`, `Writeback Stage Verification`, `Fetch Stage Sources`?**
  _High betweenness centrality (0.314) - this node is a cross-community bridge._
- **Why does `execute_config_pkg` connect `Execute/Hazard Env Packages` to `Execute Stage Verification`, `CSR Verification`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `hazard_test_pkg`, `hazard_agent_pkg`, `hazard_scoreboard_pkg` to the rest of the system?**
  _58 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Design RTL Modules` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Verification Config Packages` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Execute/Hazard Env Packages` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._