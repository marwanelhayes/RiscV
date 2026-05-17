# Graph Report - vault  (2026-05-16)

## Corpus Check
- 357 files · ~41,377 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 115 nodes · 127 edges · 13 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_CSR & Decode Verification|CSR & Decode Verification]]
- [[_COMMUNITY_Testcase Generator Functions|Testcase Generator Functions]]
- [[_COMMUNITY_Instruction Emitters|Instruction Emitters]]
- [[_COMMUNITY_Processor Configuration|Processor Configuration]]
- [[_COMMUNITY_ISE Synthesis Scripts|ISE Synthesis Scripts]]
- [[_COMMUNITY_Memory Verification Packages|Memory Verification Packages]]
- [[_COMMUNITY_FetchExecute Verification|Fetch/Execute Verification]]
- [[_COMMUNITY_Decode Stage Components|Decode Stage Components]]
- [[_COMMUNITY_Hazard Detection|Hazard Detection]]
- [[_COMMUNITY_FPU Components|FPU Components]]
- [[_COMMUNITY_RISC-V Top Level|RISC-V Top Level]]
- [[_COMMUNITY_FPU C Implementation|FPU C Implementation]]
- [[_COMMUNITY_Mux4 Component|Mux4 Component]]

## God Nodes (most connected - your core abstractions)
1. `uvm_pkg` - 13 edges
2. `add_instructions()` - 12 edges
3. `shared_pkg` - 9 edges
4. `shared_pkg.sv - ISA and register enums` - 8 edges
5. `decode_stage - Instruction decode` - 7 edges
6. `hazard_item_pkg` - 7 edges
7. `current_pc_bytes()` - 6 edges
8. `risc_fpu - Floating Point Unit` - 5 edges
9. `emit_returning_jump_template()` - 5 edges
10. `ISEExec()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Single-precision Floating Point` --defines--> `shared_pkg.sv - ISA and register enums`  [EXTRACTED]
  README.md → Design/shared_pkg.sv
- `fetch_stage - Instruction fetch` --verifies--> `fetch_top.sv - Fetch stage verification`  [EXTRACTED]
  Design/fetch_stage.sv → Verification/Fetch/fetch_top.sv
- `risc_fpu - Floating Point Unit` --instantiates--> `flp_sqrt - FPU Square Root`  [EXTRACTED]
  Design/risc_fpu.sv → Design/flp_sqrt.sv
- `decode_stage - Instruction decode` --instantiates--> `alu_decoder - ALU decoder`  [EXTRACTED]
  Design/decode_stage.sv → Design/alu_decoder.sv
- `risc_control_unit - Control unit` --instantiates--> `decode_stage - Instruction decode`  [EXTRACTED]
  Design/risc_control_unit.sv → Design/decode_stage.sv

## Communities

### Community 0 - "CSR & Decode Verification"
Cohesion: 0.14
Nodes (8): execute_item_pkg, fetch_item_pkg, shared_pkg, uvm_pkg, writeback_config_pkg, writeback_driver_pkg, writeback_item_pkg, writeback_monitor_pkg

### Community 1 - "Testcase Generator Functions"
Cohesion: 0.19
Nodes (6): add_instructions(), choose_aligned_immediate(), convert_to_hex(), generate_sb(), generate_uj(), validate_binary_instruction()

### Community 2 - "Instruction Emitters"
Cohesion: 0.19
Nodes (9): add_encoded_instruction(), current_pc_bytes(), emit_design_jal_to_pc(), emit_design_jalr_to_pc(), emit_jal(), emit_returning_jump_template(), generate_instruction(), generate_s() (+1 more)

### Community 3 - "Processor Configuration"
Cohesion: 0.17
Nodes (12): CLK_PERIOD, fetch_stage - Instruction fetch, fetch_top.sv - Fetch stage verification, FINAL_ADDR_WIDTH, FINAL_DATA_WIDTH, FINAL_PRECISION, M-extension, risc_instruction_memory - Instruction memory (+4 more)

### Community 4 - "ISE Synthesis Scripts"
Cohesion: 0.2
Nodes (2): ISEExec(), ISEStep()

### Community 5 - "Memory Verification Packages"
Cohesion: 0.22
Nodes (6): mem_config_pkg, mem_driver_pkg, mem_env_pkg, mem_item_pkg, mem_monitor_pkg, mem_seq_pkg

### Community 6 - "Fetch/Execute Verification"
Cohesion: 0.22
Nodes (4): execute_env_pkg, fetch_config_pkg, fetch_driver_pkg, fetch_monitor_pkg

### Community 7 - "Decode Stage Components"
Cohesion: 0.25
Nodes (8): alu_decoder - ALU decoder, decode_stage - Instruction decode, fp_reg_file - Floating point register file, fpu_decoder - FPU decoder, opcode_decoder - Opcode decoder, risc_control_unit - Control unit, risc_reg_file - Integer register file, riscv_processor.sv - Top-level RTL

### Community 8 - "Hazard Detection"
Cohesion: 0.25
Nodes (1): hazard_item_pkg

### Community 9 - "FPU Components"
Cohesion: 0.33
Nodes (6): execute_stage - Execute stage integration, flp_add_sub - FPU AddSub, flp_div - FPU Divide, flp_mul - FPU Multiply, flp_sqrt - FPU Square Root, risc_fpu - Floating Point Unit

### Community 10 - "RISC-V Top Level"
Cohesion: 1.0
Nodes (1): risc_test_pkg

### Community 11 - "FPU C Implementation"
Cohesion: 1.0
Nodes (0): 

### Community 12 - "Mux4 Component"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **33 isolated node(s):** `risc_test_pkg`, `execute_item_pkg`, `flp_sqrt - FPU Square Root`, `alu_decoder - ALU decoder`, `fp_reg_file - Floating point register file` (+28 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `RISC-V Top Level`** (2 nodes): `risc_test_pkg`, `risc_top.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `FPU C Implementation`** (2 nodes): `risc_fpu.c`, `risc_fpu()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Mux4 Component`** (1 nodes): `risc_mux4.sv`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `uvm_pkg` connect `CSR & Decode Verification` to `Memory Verification Packages`, `Fetch/Execute Verification`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **Why does `shared_pkg` connect `CSR & Decode Verification` to `Decode Stage Components`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `riscv_processor.sv - Top-level RTL` connect `Decode Stage Components` to `CSR & Decode Verification`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **What connects `risc_test_pkg`, `execute_item_pkg`, `flp_sqrt - FPU Square Root` to the rest of the system?**
  _33 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CSR & Decode Verification` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._