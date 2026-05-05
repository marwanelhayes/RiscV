# Graph Report - /home/marwan-ahmed/Work/RiscV  (2026-04-28)

## Corpus Check
- Large corpus: 160 files · ~609,735 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 313 nodes · 478 edges · 42 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.75)
- Token cost: 35,000 input · 28,000 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Python Testcase Generator|Python Testcase Generator]]
- [[_COMMUNITY_CSR Verification Packages|CSR Verification Packages]]
- [[_COMMUNITY_ExecuteFetch Verification|Execute/Fetch Verification]]
- [[_COMMUNITY_DecodeExecuteFPU Design|Decode/Execute/FPU Design]]
- [[_COMMUNITY_Design Modules (RTL)|Design Modules (RTL)]]
- [[_COMMUNITY_UVM Verification Framework|UVM Verification Framework]]
- [[_COMMUNITY_Memory Verification Packages|Memory Verification Packages]]
- [[_COMMUNITY_Decode Verification Packages|Decode Verification Packages]]
- [[_COMMUNITY_Writeback Verification Packages|Writeback Verification Packages]]
- [[_COMMUNITY_ISA Definitions & Parameters|ISA Definitions & Parameters]]
- [[_COMMUNITY_Synthesis Scripts|Synthesis Scripts]]
- [[_COMMUNITY_FPU Verification|FPU Verification]]
- [[_COMMUNITY_Hazard Verification|Hazard Verification]]
- [[_COMMUNITY_Execute Verification|Execute Verification]]
- [[_COMMUNITY_Fetch Verification|Fetch Verification]]
- [[_COMMUNITY_RISC FPU C Implementation|RISC FPU C Implementation]]
- [[_COMMUNITY_Synthesis Run Files|Synthesis Run Files]]
- [[_COMMUNITY_CSR Verification Top|CSR Verification Top]]
- [[_COMMUNITY_Decode Verification Top|Decode Verification Top]]
- [[_COMMUNITY_Memory Verification Top|Memory Verification Top]]
- [[_COMMUNITY_RISC Verification Top|RISC Verification Top]]
- [[_COMMUNITY_Fetch Verification Top|Fetch Verification Top]]
- [[_COMMUNITY_Writeback Verification Top|Writeback Verification Top]]
- [[_COMMUNITY_Hazard Verification Top|Hazard Verification Top]]
- [[_COMMUNITY_FPU Verification Top|FPU Verification Top]]
- [[_COMMUNITY_Execute Verification Top|Execute Verification Top]]
- [[_COMMUNITY_Python Hex Converter|Python Hex Converter]]
- [[_COMMUNITY_Sample Hex Output|Sample Hex Output]]
- [[_COMMUNITY_CSR Definitions|CSR Definitions]]
- [[_COMMUNITY_Instruction Memory|Instruction Memory]]
- [[_COMMUNITY_LZC Wrapper|LZC Wrapper]]
- [[_COMMUNITY_Non-restoring Divider|Non-restoring Divider]]
- [[_COMMUNITY_Shared Package|Shared Package]]
- [[_COMMUNITY_PC Adder|PC Adder]]
- [[_COMMUNITY_Fetch Stage|Fetch Stage]]
- [[_COMMUNITY_Mux4|Mux4]]
- [[_COMMUNITY_Data Memory|Data Memory]]
- [[_COMMUNITY_Mux3|Mux3]]
- [[_COMMUNITY_Mux2|Mux2]]
- [[_COMMUNITY_README|README]]
- [[_COMMUNITY_Synthesis HTR|Synthesis HTR]]
- [[_COMMUNITY_IP README|IP README]]

## God Nodes (most connected - your core abstractions)
1. `uvm_pkg` - 98 edges
2. `shared_pkg` - 73 edges
3. `add_instructions()` - 12 edges
4. `generate_instruction()` - 10 edges
5. `riscv_processor.sv - Top-level RTL` - 10 edges
6. `emit_returning_branch_template()` - 9 edges
7. `shared_pkg.sv - ISA and register enums` - 8 edges
8. `hazard_item_pkg` - 7 edges
9. `mem_item_pkg` - 7 edges
10. `execute_item_pkg` - 7 edges

## Surprising Connections (you probably didn't know these)
- `shared_pkg.sv - ISA and register enums` --defines--> `FINAL_DATA_WIDTH = 32`  [EXTRACTED]
  Design/shared_pkg.sv → README.md
- `shared_pkg.sv - ISA and register enums` --defines--> `FINAL_ADDR_WIDTH = 22`  [EXTRACTED]
  Design/shared_pkg.sv → README.md
- `shared_pkg.sv - ISA and register enums` --defines--> `FINAL_PRECISION = SINGLE`  [EXTRACTED]
  Design/shared_pkg.sv → README.md
- `shared_pkg.sv - ISA and register enums` --defines--> `CLK_PERIOD = 10`  [EXTRACTED]
  Design/shared_pkg.sv → README.md
- `shared_pkg.sv - ISA and register enums` --defines--> `RV32 - 32-bit Integer Base`  [EXTRACTED]
  Design/shared_pkg.sv → README.md

## Hyperedges (group relationships)
- **Five-stage pipeline** — design_fetch_stage, design_decode_stage, design_execute_stage, design_memory_stage, design_wb_stage [EXTRACTED 1.00]
- **FPU operation modules** — design_flp_add_sub, design_flp_mul, design_flp_div, design_flp_sqrt [EXTRACTED 1.00]
- **Instruction decoders** — design_opcode_decoder, design_alu_decoder, design_fpu_decoder, design_risc_control_unit [EXTRACTED 1.00]

## Communities

### Community 0 - "Python Testcase Generator"
Cohesion: 0.15
Nodes (32): add_encoded_instruction(), add_instructions(), choose_aligned_immediate(), choose_general_register(), convert_to_hex(), current_pc_bytes(), emit_addi(), emit_branch() (+24 more)

### Community 1 - "CSR Verification Packages"
Cohesion: 0.06
Nodes (20): csr_agent_pkg, csr_config_pkg, csr_driver_pkg, csr_env_pkg, csr_item_pkg, csr_monitor_pkg, csr_scoreboard_pkg, csr_seq_pkg (+12 more)

### Community 2 - "Execute/Fetch Verification"
Cohesion: 0.07
Nodes (21): execute_config_pkg, execute_driver_pkg, execute_env_pkg, execute_monitor_pkg, execute_seq_pkg, fetch_agent_pkg, fetch_config_pkg, fetch_driver_pkg (+13 more)

### Community 3 - "Decode/Execute/FPU Design"
Cohesion: 0.08
Nodes (29): alu_decoder - ALU decoder, csr_file - Control/Status Registers, decode_stage - Instruction decode, execute_stage - Execute stage integration, fetch_stage - Instruction fetch, flp_add_sub - FPU Add/Sub, flp_div - FPU Divide, flp_mul - FPU Multiply (+21 more)

### Community 4 - "Design Modules (RTL)"
Cohesion: 0.07
Nodes (1): shared_pkg

### Community 5 - "UVM Verification Framework"
Cohesion: 0.09
Nodes (1): uvm_pkg

### Community 6 - "Memory Verification Packages"
Cohesion: 0.11
Nodes (9): mem_agent_pkg, mem_config_pkg, mem_driver_pkg, mem_env_pkg, mem_item_pkg, mem_monitor_pkg, mem_scoreboard_pkg, mem_seq_pkg (+1 more)

### Community 7 - "Decode Verification Packages"
Cohesion: 0.11
Nodes (9): decode_agent_pkg, decode_config_pkg, decode_driver_pkg, decode_env_pkg, decode_item_pkg, decode_monitor_pkg, decode_scoreboard_pkg, decode_seq_pkg (+1 more)

### Community 8 - "Writeback Verification Packages"
Cohesion: 0.11
Nodes (9): writeback_agent_pkg, writeback_config_pkg, writeback_driver_pkg, writeback_env_pkg, writeback_item_pkg, writeback_monitor_pkg, writeback_scoreboard_pkg, writeback_seq_pkg (+1 more)

### Community 9 - "ISA Definitions & Parameters"
Cohesion: 0.22
Nodes (9): shared_pkg.sv - ISA and register enums, M-extension - Integer Multiply/Divide, RV32 - 32-bit Integer Base, Single-precision Floating Point, CLK_PERIOD = 10, FINAL_ADDR_WIDTH = 22, FINAL_DATA_WIDTH = 32, FINAL_PRECISION = SINGLE (+1 more)

### Community 10 - "Synthesis Scripts"
Cohesion: 0.57
Nodes (7): ISEExec(), ISEInit(), ISEOpenFile(), ISEStdErr(), ISEStdOut(), ISEStep(), ISETouchFile()

### Community 11 - "FPU Verification"
Cohesion: 0.29
Nodes (1): flp_item_pkg

### Community 12 - "Hazard Verification"
Cohesion: 0.29
Nodes (1): hazard_item_pkg

### Community 13 - "Execute Verification"
Cohesion: 0.29
Nodes (1): execute_item_pkg

### Community 14 - "Fetch Verification"
Cohesion: 0.29
Nodes (1): fetch_item_pkg

### Community 15 - "RISC FPU C Implementation"
Cohesion: 1.0
Nodes (0): 

### Community 16 - "Synthesis Run Files"
Cohesion: 1.0
Nodes (0): 

### Community 17 - "CSR Verification Top"
Cohesion: 1.0
Nodes (1): csr_test_pkg

### Community 18 - "Decode Verification Top"
Cohesion: 1.0
Nodes (1): decode_test_pkg

### Community 19 - "Memory Verification Top"
Cohesion: 1.0
Nodes (1): mem_test_pkg

### Community 20 - "RISC Verification Top"
Cohesion: 1.0
Nodes (1): risc_test_pkg

### Community 21 - "Fetch Verification Top"
Cohesion: 1.0
Nodes (1): fetch_test_pkg

### Community 22 - "Writeback Verification Top"
Cohesion: 1.0
Nodes (1): writeback_test_pkg

### Community 23 - "Hazard Verification Top"
Cohesion: 1.0
Nodes (1): hazard_test_pkg

### Community 24 - "FPU Verification Top"
Cohesion: 1.0
Nodes (1): flp_test_pkg

### Community 25 - "Execute Verification Top"
Cohesion: 1.0
Nodes (1): execute_test_pkg

### Community 26 - "Python Hex Converter"
Cohesion: 1.0
Nodes (0): 

### Community 27 - "Sample Hex Output"
Cohesion: 1.0
Nodes (0): 

### Community 28 - "CSR Definitions"
Cohesion: 1.0
Nodes (0): 

### Community 29 - "Instruction Memory"
Cohesion: 1.0
Nodes (0): 

### Community 30 - "LZC Wrapper"
Cohesion: 1.0
Nodes (0): 

### Community 31 - "Non-restoring Divider"
Cohesion: 1.0
Nodes (0): 

### Community 32 - "Shared Package"
Cohesion: 1.0
Nodes (0): 

### Community 33 - "PC Adder"
Cohesion: 1.0
Nodes (0): 

### Community 34 - "Fetch Stage"
Cohesion: 1.0
Nodes (0): 

### Community 35 - "Mux4"
Cohesion: 1.0
Nodes (0): 

### Community 36 - "Data Memory"
Cohesion: 1.0
Nodes (0): 

### Community 37 - "Mux3"
Cohesion: 1.0
Nodes (0): 

### Community 38 - "Mux2"
Cohesion: 1.0
Nodes (0): 

### Community 39 - "README"
Cohesion: 1.0
Nodes (1): RISC-V Processor Repository Guide

### Community 40 - "Synthesis HTR"
Cohesion: 1.0
Nodes (1): htr.txt - Vivado synthesis script

### Community 41 - "IP README"
Cohesion: 1.0
Nodes (1): IP user files notice

## Knowledge Gaps
- **84 isolated node(s):** `hazard_test_pkg`, `hazard_agent_pkg`, `hazard_scoreboard_pkg`, `hazard_subscriber_pkg`, `hazard_seq_pkg` (+79 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `RISC FPU C Implementation`** (2 nodes): `risc_fpu.c`, `risc_fpu()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Synthesis Run Files`** (2 nodes): `EAInclude()`, `rundef.js`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `CSR Verification Top`** (2 nodes): `csr_test_pkg`, `csr_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Decode Verification Top`** (2 nodes): `decode_test_pkg`, `decode_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Memory Verification Top`** (2 nodes): `mem_test_pkg`, `mem_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `RISC Verification Top`** (2 nodes): `risc_test_pkg`, `risc_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Fetch Verification Top`** (2 nodes): `fetch_test_pkg`, `fetch_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Writeback Verification Top`** (2 nodes): `writeback_top.sv`, `writeback_test_pkg`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Hazard Verification Top`** (2 nodes): `hazard_test_pkg`, `hazard_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `FPU Verification Top`** (2 nodes): `flp_test_pkg`, `flp_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Execute Verification Top`** (2 nodes): `execute_test_pkg`, `execute_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Python Hex Converter`** (1 nodes): `hex1.v`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Sample Hex Output`** (1 nodes): `sample_hex.v`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `CSR Definitions`** (1 nodes): `csr_defs.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Instruction Memory`** (1 nodes): `risc_instruction_memory.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `LZC Wrapper`** (1 nodes): `lzc_wr.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Non-restoring Divider`** (1 nodes): `non_restoring_divider.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Shared Package`** (1 nodes): `shared_pkg.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `PC Adder`** (1 nodes): `pc_adder.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Fetch Stage`** (1 nodes): `fetch_stage.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux4`** (1 nodes): `risc_mux4.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Data Memory`** (1 nodes): `data_memory.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux3`** (1 nodes): `risc_mux3.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux2`** (1 nodes): `risc_mux2.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `README`** (1 nodes): `RISC-V Processor Repository Guide`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Synthesis HTR`** (1 nodes): `htr.txt - Vivado synthesis script`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `IP README`** (1 nodes): `IP user files notice`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `uvm_pkg` connect `UVM Verification Framework` to `CSR Verification Packages`, `Execute/Fetch Verification`, `Design Modules (RTL)`, `Memory Verification Packages`, `Decode Verification Packages`, `Writeback Verification Packages`, `FPU Verification`, `Hazard Verification`, `Execute Verification`, `Fetch Verification`, `CSR Verification Top`, `Decode Verification Top`, `Memory Verification Top`, `RISC Verification Top`, `Fetch Verification Top`, `Writeback Verification Top`, `Hazard Verification Top`, `FPU Verification Top`, `Execute Verification Top`?**
  _High betweenness centrality (0.358) - this node is a cross-community bridge._
- **Why does `shared_pkg` connect `Design Modules (RTL)` to `CSR Verification Packages`, `Execute/Fetch Verification`, `UVM Verification Framework`, `Memory Verification Packages`, `Decode Verification Packages`, `Writeback Verification Packages`, `FPU Verification`, `Hazard Verification`, `Execute Verification`, `Fetch Verification`, `CSR Verification Top`, `Decode Verification Top`, `Memory Verification Top`, `RISC Verification Top`, `Fetch Verification Top`, `Writeback Verification Top`, `Hazard Verification Top`, `FPU Verification Top`, `Execute Verification Top`?**
  _High betweenness centrality (0.141) - this node is a cross-community bridge._
- **Why does `riscv_processor.sv - Top-level RTL` connect `Decode/Execute/FPU Design` to `ISA Definitions & Parameters`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `hazard_test_pkg`, `hazard_agent_pkg`, `hazard_scoreboard_pkg` to the rest of the system?**
  _84 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CSR Verification Packages` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Execute/Fetch Verification` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Decode/Execute/FPU Design` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._