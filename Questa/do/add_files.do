# =============================================================================
# compile.do
# -----------------------------------------------------------------------------
# Questa simulation compile script for RISC-V processor
# Usage: do ../add_files.do
# =============================================================================

# Compile shared packages first (dependencies)
echo "Adding shared packages..."

# Design packages
project addfile ../../Design/shared_pkg.sv
project addfile ../../Design/csr_defs.sv

# Design modules - core pipeline stages
echo "Adding design modules - Pipeline stages..."
project addfile ../../Design/fetch_stage.sv
project addfile ../../Design/decode_stage.sv
project addfile ../../Design/execute_stage.sv
project addfile ../../Design/memory_stage.sv
project addfile ../../Design/wb_stage.sv

# Control units
echo "Adding control units..."
project addfile ../../Design/risc_control_unit.sv
project addfile ../../Design/opcode_decoder.sv
project addfile ../../Design/alu_decoder.sv
project addfile ../../Design/fpu_decoder.sv

# ALU and execution components
echo "Adding ALU components..."
project addfile ../../Design/risc_alu.sv
project addfile ../../Design/wallace_tree.sv
project addfile ../../Design/non_restoring_divider.sv
project addfile ../../Design/lzc_wr.sv

# Register files
echo "Adding register files..."
project addfile ../../Design/risc_reg_file.sv
project addfile ../../Design/risc_mem.sv
project addfile ../../Design/fp_reg_file.sv

# Memory
echo "Adding memory modules..."
project addfile ../../Design/risc_instruction_memory.sv
project addfile ../../Design/risc_data_memory.sv
project addfile ../../Design/data_memory.sv

# CSR
echo "Adding CSR modules..."
project addfile ../../Design/csr_file.sv

# FPU
echo "Adding FPU modules..."
project addfile ../../Design/risc_fpu.sv
project addfile ../../Design/flp_add_sub.sv
project addfile ../../Design/flp_mul.sv
project addfile ../../Design/flp_div.sv
project addfile ../../Design/flp_sqrt.sv

# Multiplexers and utilities
echo "Adding multiplexers and utilities..."
project addfile ../../Design/risc_mux2.sv
project addfile ../../Design/risc_mux3.sv
project addfile ../../Design/risc_mux4.sv
project addfile ../../Design/pc_adder.sv

# Hazard unit
echo "Adding hazard unit..."
project addfile ../../Design/hazard_unit.sv

# Top-level processor
echo "Adding top-level processor..."
project addfile ../../Design/riscv_processor.sv

# Verification packages - Fetch stage
echo "Adding Fetch verification..."
project addfile ../../Verification/Fetch/fetch_item_pkg.sv
project addfile ../../Verification/Fetch/fetch_config_pkg.sv
project addfile ../../Verification/Fetch/fetch_driver_pkg.sv
project addfile ../../Verification/Fetch/fetch_monitor_pkg.sv
project addfile ../../Verification/Fetch/fetch_seq_pkg.sv
project addfile ../../Verification/Fetch/fetch_agent_pkg.sv
project addfile ../../Verification/Fetch/fetch_scoreboard_pkg.sv
project addfile ../../Verification/Fetch/fetch_subscriber_pkg.sv
project addfile ../../Verification/Fetch/fetch_env_pkg.sv
project addfile ../../Verification/Fetch/fetch_test_pkg.sv
project addfile ../../Verification/Fetch/fetch_interface.sv
project addfile ../../Verification/Fetch/fetch_top.sv

# Verification packages - Decode stage
echo "Adding Decode verification..."
project addfile ../../Verification/Decode/decode_item_pkg.sv
project addfile ../../Verification/Decode/decode_config_pkg.sv
project addfile ../../Verification/Decode/decode_driver_pkg.sv
project addfile ../../Verification/Decode/decode_monitor_pkg.sv
project addfile ../../Verification/Decode/decode_seq_pkg.sv
project addfile ../../Verification/Decode/decode_agent_pkg.sv
project addfile ../../Verification/Decode/decode_scoreboard_pkg.sv
project addfile ../../Verification/Decode/decode_subscriber_pkg.sv
project addfile ../../Verification/Decode/decode_env_pkg.sv

# Verification packages - Execute stage
echo "Adding Execute verification..."
project addfile ../../Verification/Execute/execute_item_pkg.sv
project addfile ../../Verification/Execute/execute_config_pkg.sv
project addfile ../../Verification/Execute/execute_driver_pkg.sv
project addfile ../../Verification/Execute/execute_monitor_pkg.sv
project addfile ../../Verification/Execute/execute_seq_pkg.sv
project addfile ../../Verification/Execute/execute_agent_pkg.sv
project addfile ../../Verification/Execute/execute_scoreboard_pkg.sv
project addfile ../../Verification/Execute/execute_subscriber_pkg.sv
project addfile ../../Verification/Execute/execute_env_pkg.sv
project addfile ../../Verification/Execute/execute_test_pkg.sv
project addfile ../../Verification/Execute/execute_interface.sv
project addfile ../../Verification/Execute/execute_top.sv

# Verification packages - Memory stage
echo "Adding Memory verification..."
project addfile ../../Verification/Memory/mem_item_pkg.sv
project addfile ../../Verification/Memory/mem_config_pkg.sv
project addfile ../../Verification/Memory/mem_driver_pkg.sv
project addfile ../../Verification/Memory/mem_monitor_pkg.sv
project addfile ../../Verification/Memory/mem_seq_pkg.sv
project addfile ../../Verification/Memory/mem_agent_pkg.sv
project addfile ../../Verification/Memory/mem_scoreboard_pkg.sv
project addfile ../../Verification/Memory/mem_subscriber_pkg.sv
project addfile ../../Verification/Memory/mem_env_pkg.sv
project addfile ../../Verification/Memory/mem_test_pkg.sv
project addfile ../../Verification/Memory/mem_interface.sv
project addfile ../../Verification/Memory/mem_top.sv

# Verification packages - WriteBack stage
echo "Adding WriteBack verification..."
project addfile ../../Verification/WriteBack/writeback_item_pkg.sv
project addfile ../../Verification/WriteBack/writeback_config_pkg.sv
project addfile ../../Verification/WriteBack/writeback_driver_pkg.sv
project addfile ../../Verification/WriteBack/writeback_monitor_pkg.sv
project addfile ../../Verification/WriteBack/writeback_seq_pkg.sv
project addfile ../../Verification/WriteBack/writeback_agent_pkg.sv
project addfile ../../Verification/WriteBack/writeback_scoreboard_pkg.sv
project addfile ../../Verification/WriteBack/writeback_subscriber_pkg.sv
project addfile ../../Verification/WriteBack/writeback_env_pkg.sv
project addfile ../../Verification/WriteBack/writeback_test_pkg.sv
project addfile ../../Verification/WriteBack/writeback_interface.sv
project addfile ../../Verification/WriteBack/writeback_top.sv

# Verification packages - FPU
echo "Adding FPU verification..."
project addfile ../../Verification/FPU/flp_item_pkg.sv
project addfile ../../Verification/FPU/flp_config_pkg.sv
project addfile ../../Verification/FPU/flp_driver_pkg.sv
project addfile ../../Verification/FPU/flp_monitor_pkg.sv
project addfile ../../Verification/FPU/flp_seq_pkg.sv
project addfile ../../Verification/FPU/flp_agent_pkg.sv
project addfile ../../Verification/FPU/flp_scoreboard_pkg.sv
project addfile ../../Verification/FPU/flp_subscriber_pkg.sv
project addfile ../../Verification/FPU/flp_env_pkg.sv
project addfile ../../Verification/FPU/flp_test_pkg.sv
project addfile ../../Verification/FPU/flp_interface.sv
project addfile ../../Verification/FPU/flp_top.sv

# Verification packages - CSR
echo "Adding CSR verification..."
project addfile ../../Verification/CSR/csr_item_pkg.sv
project addfile ../../Verification/CSR/csr_config_pkg.sv
project addfile ../../Verification/CSR/csr_driver_pkg.sv
project addfile ../../Verification/CSR/csr_monitor_pkg.sv
project addfile ../../Verification/CSR/csr_seq_pkg.sv
project addfile ../../Verification/CSR/csr_agent_pkg.sv
project addfile ../../Verification/CSR/csr_scoreboard_pkg.sv
project addfile ../../Verification/CSR/csr_subscriber_pkg.sv
project addfile ../../Verification/CSR/csr_env_pkg.sv
project addfile ../../Verification/CSR/csr_test_pkg.sv
project addfile ../../Verification/CSR/csr_interface.sv
project addfile ../../Verification/CSR/csr_top.sv

# Verification packages - Hazard
echo "Adding Hazard verification..."
project addfile ../../Verification/Hazard/hazard_item_pkg.sv
project addfile ../../Verification/Hazard/hazard_config_pkg.sv
project addfile ../../Verification/Hazard/hazard_driver_pkg.sv
project addfile ../../Verification/Hazard/hazard_monitor_pkg.sv
project addfile ../../Verification/Hazard/hazard_seq_pkg.sv
project addfile ../../Verification/Hazard/hazard_agent_pkg.sv
project addfile ../../Verification/Hazard/hazard_scoreboard_pkg.sv
project addfile ../../Verification/Hazard/hazard_subscriber_pkg.sv
project addfile ../../Verification/Hazard/hazard_env_pkg.sv
project addfile ../../Verification/Hazard/hazard_test_pkg.sv
project addfile ../../Verification/Hazard/hazard_interface.sv
project addfile ../../Verification/Hazard/hazard_top.sv

# Verification packages - Risc (full processor)
echo "Adding Risc full processor verification..."
project addfile ../../Verification/Risc/risc_interface.sv
project addfile ../../Verification/Risc/risc_test_pkg.sv
project addfile ../../Verification/Risc/risc_top.sv

echo "Adding complete!"