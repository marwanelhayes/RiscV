# =============================================================================
# add_files.do
# -----------------------------------------------------------------------------
# Adds every design and verification file to the open Questa project (GUI
# flow). Paths are resolved from this script's location.
#
# Usage (with the project open): do <repo>/Questa/do/add_files.do
# =============================================================================

set ROOT [file normalize [file join [file dirname [file normalize [status file]]] .. ..]]

# Shared packages first (dependencies)
echo "Adding shared packages..."

# Design packages
project addfile $ROOT/Design/shared_pkg.sv
project addfile $ROOT/Design/csr_defs.sv

# Design modules - core pipeline stages
echo "Adding design modules - Pipeline stages..."
project addfile $ROOT/Design/fetch_stage.sv
project addfile $ROOT/Design/decode_stage.sv
project addfile $ROOT/Design/execute_stage.sv
project addfile $ROOT/Design/memory_stage.sv
project addfile $ROOT/Design/amo_unit.sv
project addfile $ROOT/Design/wb_stage.sv

# Control units
echo "Adding control units..."
project addfile $ROOT/Design/risc_control_unit.sv
project addfile $ROOT/Design/opcode_decoder.sv
project addfile $ROOT/Design/alu_decoder.sv
project addfile $ROOT/Design/fpu_decoder.sv

# ALU and execution components
echo "Adding ALU components..."
project addfile $ROOT/Design/risc_alu.sv
project addfile $ROOT/Design/wallace_tree.sv
project addfile $ROOT/Design/non_restoring_divider.sv
project addfile $ROOT/Design/lzc_wr.sv

# Register files
echo "Adding register files..."
project addfile $ROOT/Design/risc_reg_file.sv
project addfile $ROOT/Design/risc_mem.sv
project addfile $ROOT/Design/fp_reg_file.sv

# Memory
echo "Adding memory modules..."
project addfile $ROOT/Design/risc_instruction_memory.sv
project addfile $ROOT/Design/risc_data_memory.sv
project addfile $ROOT/Design/cache.sv
project addfile $ROOT/Verification/Memory/cache_sva.sv

# CSR
echo "Adding CSR modules..."
project addfile $ROOT/Design/csr_file.sv

# FPU
echo "Adding FPU modules..."
project addfile $ROOT/Design/risc_fpu.sv
project addfile $ROOT/Design/flp_add_sub.sv
project addfile $ROOT/Design/flp_mul.sv
project addfile $ROOT/Design/flp_div.sv
project addfile $ROOT/Design/flp_sqrt.sv

# Multiplexers and utilities
echo "Adding multiplexers and utilities..."
project addfile $ROOT/Design/risc_mux2.sv
project addfile $ROOT/Design/risc_mux3.sv
project addfile $ROOT/Design/risc_mux4.sv
project addfile $ROOT/Design/pc_adder.sv

# Hazard unit
echo "Adding hazard unit..."
project addfile $ROOT/Design/hazard_unit.sv

# Top-level processor
echo "Adding top-level processor..."
project addfile $ROOT/Design/riscv_processor.sv

# Verification packages - Fetch stage
echo "Adding Fetch verification..."
project addfile $ROOT/Verification/Fetch/fetch_item_pkg.sv
project addfile $ROOT/Verification/Common/tb_base_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_config_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_driver_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_monitor_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_seq_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_agent_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_scoreboard_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_subscriber_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_reg_block_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_mem_checker_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_predictor_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_env_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_test_pkg.sv
project addfile $ROOT/Verification/Fetch/fetch_interface.sv
project addfile $ROOT/Verification/Fetch/fetch_top.sv

# Verification packages - Decode stage
echo "Adding Decode verification..."
project addfile $ROOT/Verification/Decode/decode_item_pkg.sv
project addfile $ROOT/Verification/Decode/decode_interface.sv
project addfile $ROOT/Verification/Decode/decode_config_pkg.sv
project addfile $ROOT/Verification/Decode/decode_driver_pkg.sv
project addfile $ROOT/Verification/Decode/decode_monitor_pkg.sv
project addfile $ROOT/Verification/Decode/decode_seq_pkg.sv
project addfile $ROOT/Verification/Decode/decode_agent_pkg.sv
project addfile $ROOT/Verification/Decode/decode_scoreboard_pkg.sv
project addfile $ROOT/Verification/Decode/decode_subscriber_pkg.sv
project addfile $ROOT/Verification/Decode/decode_gpr_reg_pkg.sv
project addfile $ROOT/Verification/Decode/decode_fpr_reg_pkg.sv
project addfile $ROOT/Verification/Decode/decode_reg_block_pkg.sv
project addfile $ROOT/Verification/Decode/decode_predictor_pkg.sv
project addfile $ROOT/Verification/Decode/decode_reg_checker_pkg.sv
project addfile $ROOT/Verification/Decode/decode_env_pkg.sv
project addfile $ROOT/Verification/Decode/decode_test_pkg.sv
project addfile $ROOT/Verification/Decode/decode_top.sv

# Verification packages - Execute stage
echo "Adding Execute verification..."
project addfile $ROOT/Verification/Execute/execute_item_pkg.sv
project addfile $ROOT/Verification/Execute/execute_config_pkg.sv
project addfile $ROOT/Verification/Execute/execute_driver_pkg.sv
project addfile $ROOT/Verification/Execute/execute_monitor_pkg.sv
project addfile $ROOT/Verification/Execute/execute_seq_pkg.sv
project addfile $ROOT/Verification/Execute/execute_agent_pkg.sv
project addfile $ROOT/Verification/Execute/execute_scoreboard_pkg.sv
project addfile $ROOT/Verification/Execute/execute_subscriber_pkg.sv
project addfile $ROOT/Verification/Execute/execute_predictor_pkg.sv
project addfile $ROOT/Verification/Execute/execute_env_pkg.sv
project addfile $ROOT/Verification/Execute/execute_test_pkg.sv
project addfile $ROOT/Verification/Execute/execute_interface.sv
project addfile $ROOT/Verification/Execute/execute_top.sv

# Verification packages - Memory stage
echo "Adding Memory verification..."
project addfile $ROOT/Verification/Memory/mem_item_pkg.sv
project addfile $ROOT/Verification/Memory/mem_config_pkg.sv
project addfile $ROOT/Verification/Memory/mem_driver_pkg.sv
project addfile $ROOT/Verification/Memory/mem_monitor_pkg.sv
project addfile $ROOT/Verification/Memory/mem_seq_pkg.sv
project addfile $ROOT/Verification/Memory/mem_agent_pkg.sv
project addfile $ROOT/Verification/Memory/mem_scoreboard_pkg.sv
project addfile $ROOT/Verification/Memory/mem_subscriber_pkg.sv
project addfile $ROOT/Verification/Memory/mem_flat_predictor_pkg.sv
project addfile $ROOT/Verification/Memory/mem_reg_block_pkg.sv
project addfile $ROOT/Verification/Memory/mem_ral_checker_pkg.sv
project addfile $ROOT/Verification/Memory/mem_env_pkg.sv
project addfile $ROOT/Verification/Memory/mem_test_pkg.sv
project addfile $ROOT/Verification/Memory/mem_interface.sv
project addfile $ROOT/Verification/Memory/mem_top.sv

# Verification packages - WriteBack stage
echo "Adding WriteBack verification..."
project addfile $ROOT/Verification/WriteBack/writeback_item_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_config_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_driver_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_monitor_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_seq_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_agent_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_scoreboard_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_subscriber_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_predictor_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_env_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_test_pkg.sv
project addfile $ROOT/Verification/WriteBack/writeback_interface.sv
project addfile $ROOT/Verification/WriteBack/writeback_top.sv

# Verification packages - FPU
echo "Adding FPU verification..."
project addfile $ROOT/Verification/FPU/flp_item_pkg.sv
project addfile $ROOT/Verification/FPU/flp_config_pkg.sv
project addfile $ROOT/Verification/FPU/flp_driver_pkg.sv
project addfile $ROOT/Verification/FPU/flp_monitor_pkg.sv
project addfile $ROOT/Verification/FPU/flp_seq_pkg.sv
project addfile $ROOT/Verification/FPU/flp_agent_pkg.sv
project addfile $ROOT/Verification/FPU/flp_scoreboard_pkg.sv
project addfile $ROOT/Verification/FPU/flp_subscriber_pkg.sv
project addfile $ROOT/Verification/FPU/flp_predictor_pkg.sv
project addfile $ROOT/Verification/FPU/flp_env_pkg.sv
project addfile $ROOT/Verification/FPU/flp_test_pkg.sv
project addfile $ROOT/Verification/FPU/flp_interface.sv
project addfile $ROOT/Verification/FPU/flp_top.sv

# Verification packages - CSR
echo "Adding CSR verification..."
project addfile $ROOT/Verification/CSR/csr_item_pkg.sv
project addfile $ROOT/Verification/CSR/csr_config_pkg.sv
project addfile $ROOT/Verification/CSR/csr_driver_pkg.sv
project addfile $ROOT/Verification/CSR/csr_monitor_pkg.sv
project addfile $ROOT/Verification/CSR/csr_seq_pkg.sv
project addfile $ROOT/Verification/CSR/csr_agent_pkg.sv
project addfile $ROOT/Verification/CSR/csr_scoreboard_pkg.sv
project addfile $ROOT/Verification/CSR/csr_subscriber_pkg.sv
project addfile $ROOT/Verification/CSR/csr_reg_block_pkg.sv
project addfile $ROOT/Verification/CSR/csr_predictor_pkg.sv
project addfile $ROOT/Verification/CSR/csr_reg_checker_pkg.sv
project addfile $ROOT/Verification/CSR/csr_env_pkg.sv
project addfile $ROOT/Verification/CSR/csr_test_pkg.sv
project addfile $ROOT/Verification/CSR/csr_interface.sv
project addfile $ROOT/Verification/CSR/csr_top.sv

# Verification packages - Hazard
echo "Adding Hazard verification..."
project addfile $ROOT/Verification/Hazard/hazard_item_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_config_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_driver_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_monitor_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_seq_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_agent_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_scoreboard_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_subscriber_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_predictor_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_env_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_test_pkg.sv
project addfile $ROOT/Verification/Hazard/hazard_interface.sv
project addfile $ROOT/Verification/Hazard/hazard_top.sv

# Reusable protocol assertion modules
echo "Adding reusable assertions module"
project addfile $ROOT/Verification/Protocol/AXI_Assertions.sv
project addfile $ROOT/Verification/Fetch/fetch_sva.sv
project addfile $ROOT/Verification/Decode/decode_sva.sv
project addfile $ROOT/Verification/Execute/execute_sva.sv
project addfile $ROOT/Verification/Memory/memory_sva.sv
project addfile $ROOT/Verification/WriteBack/wb_sva.sv
project addfile $ROOT/Verification/Hazard/hazard_sva.sv
project addfile $ROOT/Verification/FPU/fpu_sva.sv
project addfile $ROOT/Verification/CSR/csr_sva.sv
project addfile $ROOT/Verification/Protocol/axi_interface.sv

# Verification packages - Risc (full processor)
echo "Adding Risc full processor verification..."
project addfile $ROOT/Verification/Risc/csr_wr.sv
project addfile $ROOT/Verification/Risc/decode_wr.sv
project addfile $ROOT/Verification/Risc/execute_wr.sv
project addfile $ROOT/Verification/Risc/fetch_wr.sv
project addfile $ROOT/Verification/Risc/flp_wr.sv
project addfile $ROOT/Verification/Risc/hazard_wr.sv
project addfile $ROOT/Verification/Risc/memory_wr.sv
project addfile $ROOT/Verification/Risc/wb_wr.sv
project addfile $ROOT/Verification/Risc/risc_interface.sv
project addfile $ROOT/Verification/Risc/risc_test_pkg.sv
project addfile $ROOT/Verification/Risc/risc_top.sv

echo "Adding complete!"
