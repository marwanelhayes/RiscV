# =============================================================================
# compile.do
# -----------------------------------------------------------------------------
# Questa simulation compile script for RISC-V processor
# Usage: do ../compile.do
# =============================================================================

# Compile shared packages first (dependencies)
echo "Compiling shared packages..."

# Design packages
vlog -work work -vopt -stats=none ../../Design/shared_pkg.sv
vlog -work work -vopt -stats=none ../../Design/csr_defs.sv

# Design modules - core pipeline stages
echo "Compiling design modules - Pipeline stages..."
vlog -work work -vopt -stats=none ../../Design/fetch_stage.sv
vlog -work work -vopt -stats=none ../../Design/decode_stage.sv
vlog -work work -vopt -stats=none ../../Design/execute_stage.sv
vlog -work work -vopt -stats=none ../../Design/memory_stage.sv
vlog -work work -vopt -stats=none ../../Design/wb_stage.sv

# Control units
echo "Compiling control units..."
vlog -work work -vopt -stats=none ../../Design/risc_control_unit.sv
vlog -work work -vopt -stats=none ../../Design/opcode_decoder.sv
vlog -work work -vopt -stats=none ../../Design/alu_decoder.sv
vlog -work work -vopt -stats=none ../../Design/fpu_decoder.sv

# ALU and execution components
echo "Compiling ALU components..."
vlog -work work -vopt -stats=none ../../Design/risc_alu.sv
vlog -work work -vopt -stats=none ../../Design/wallace_tree.sv
vlog -work work -vopt -stats=none ../../Design/non_restoring_divider.sv
vlog -work work -vopt -stats=none ../../Design/lzc_wr.sv

# Register files
echo "Compiling register files..."
vlog -work work -vopt -stats=none ../../Design/risc_reg_file.sv
vlog -work work -vopt -stats=none ../../Design/risc_mem.sv
vlog -work work -vopt -stats=none ../../Design/fp_reg_file.sv

# Memory
echo "Compiling memory modules..."
vlog -work work -vopt -stats=none ../../Design/risc_instruction_memory.sv
vlog -work work -vopt -stats=none ../../Design/risc_data_memory.sv
vlog -work work -vopt -stats=none ../../Design/data_memory.sv

# CSR
echo "Compiling CSR modules..."
vlog -work work -vopt -stats=none ../../Design/csr_file.sv

# FPU
echo "Compiling FPU modules..."
vlog -work work -vopt -stats=none ../../Design/risc_fpu.sv
vlog -work work -vopt -stats=none ../../Design/flp_add_sub.sv
vlog -work work -vopt -stats=none ../../Design/flp_mul.sv
vlog -work work -vopt -stats=none ../../Design/flp_div.sv
vlog -work work -vopt -stats=none ../../Design/flp_sqrt.sv

# Multiplexers and utilities
echo "Compiling multiplexers and utilities..."
vlog -work work -vopt -stats=none ../../Design/risc_mux2.sv
vlog -work work -vopt -stats=none ../../Design/risc_mux3.sv
vlog -work work -vopt -stats=none ../../Design/risc_mux4.sv
vlog -work work -vopt -stats=none ../../Design/pc_adder.sv

# Hazard unit
echo "Compiling hazard unit..."
vlog -work work -vopt -stats=none ../../Design/hazard_unit.sv

# Top-level processor
echo "Compiling top-level processor..."
vlog -work work -vopt -stats=none ../../Design/riscv_processor.sv

# Verification packages - Fetch stage
echo "Compiling Fetch verification..."
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_interface.sv
vlog -work work -vopt -stats=none ../../Verification/Fetch/fetch_top.sv

# Verification packages - Decode stage
echo "Compiling Decode verification..."
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Decode/decode_env_pkg.sv

# Verification packages - Execute stage
echo "Compiling Execute verification..."
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_interface.sv
vlog -work work -vopt -stats=none ../../Verification/Execute/execute_top.sv

# Verification packages - Memory stage
echo "Compiling Memory verification..."
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_interface.sv
vlog -work work -vopt -stats=none ../../Verification/Memory/mem_top.sv

# Verification packages - WriteBack stage
echo "Compiling WriteBack verification..."
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_interface.sv
vlog -work work -vopt -stats=none ../../Verification/WriteBack/writeback_top.sv

# Verification packages - FPU
echo "Compiling FPU verification..."
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_interface.sv
vlog -work work -vopt -stats=none ../../Verification/FPU/flp_top.sv

# Verification packages - CSR
echo "Compiling CSR verification..."
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_interface.sv
vlog -work work -vopt -stats=none ../../Verification/CSR/csr_top.sv

# Verification packages - Hazard
echo "Compiling Hazard verification..."
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_item_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_config_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_driver_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_monitor_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_seq_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_agent_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_scoreboard_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_subscriber_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_env_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_interface.sv
vlog -work work -vopt -stats=none ../../Verification/Hazard/hazard_top.sv

# Verification packages - Risc (full processor)
echo "Compiling Risc full processor verification..."
vlog -work work -vopt -stats=none ../../Verification/Risc/risc_interface.sv
vlog -work work -vopt -stats=none ../../Verification/Risc/risc_test_pkg.sv
vlog -work work -vopt -stats=none ../../Verification/Risc/risc_top.sv

echo "Compiling complete!"