# =============================================================================
# compile.do
# -----------------------------------------------------------------------------
# Compiles every design and verification file into the library "work" of the
# current directory. Paths are resolved from this script's location, so it
# runs from any directory.
#
# Usage:
#   do <repo>/Scripts/compile.do                     (XLEN 32)
#   set XLEN 64; do <repo>/Scripts/compile.do      (RV64 core)
# =============================================================================

set ROOT [file normalize [file join [file dirname [file normalize [status file]]] ..]]
if {![info exists XLEN]} {set XLEN 32}

# Fresh work library every compile: no stale design units from an earlier run
catch {vdel -lib work -all}

# Compile shared packages first (dependencies)
echo "Compiling shared packages..."

# Design packages
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/shared_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/csr_defs.sv

# Reusable protocol assertion modules
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Protocol/AXI_Assertions.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/memory_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/wb_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/fpu_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_sva.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Protocol/axi_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Protocol/axi_random_stall.sv

# Shared reference models (exact FP reference, ISA golden model)
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_ref_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/riscv_iss_pkg.sv

# Design modules - core pipeline stages
echo "Compiling design modules - Pipeline stages..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/fetch_stage.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/decode_stage.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/execute_stage.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/memory_stage.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/amo_unit.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/wb_stage.sv

# Control units
echo "Compiling control units..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_control_unit.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/opcode_decoder.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/alu_decoder.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/fpu_decoder.sv

# ALU and execution components
echo "Compiling ALU components..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_alu.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/wallace_tree.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/non_restoring_divider.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/lzc_wr.sv

# Register files
echo "Compiling register files..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_reg_file.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_mem.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/fp_reg_file.sv

# Memory
echo "Compiling memory modules..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_instruction_memory.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_data_memory.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/cache.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/cache_sva.sv

# CSR
echo "Compiling CSR modules..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/csr_file.sv

# FPU
echo "Compiling FPU modules..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_fpu.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/flp_add_sub.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/flp_mul.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/flp_div.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/flp_sqrt.sv

# Multiplexers and utilities
echo "Compiling multiplexers and utilities..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_mux2.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_mux3.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/risc_mux4.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/pc_adder.sv

# Hazard unit
echo "Compiling hazard unit..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/hazard_unit.sv

# Top-level processor
echo "Compiling top-level processor..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Design/riscv_processor.sv

# Verification packages - Fetch stage
# Shared UVM base classes (every unit environment extends them)
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Common/tb_base_pkg.sv

echo "Compiling Fetch verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_reg_block_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_mem_checker_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Fetch/fetch_top.sv

# Verification packages - Decode stage
echo "Compiling Decode verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_gpr_reg_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_fpr_reg_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_reg_block_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_reg_checker_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Decode/decode_top.sv

# Verification packages - FPU
echo "Compiling FPU verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/FPU/flp_top.sv

# Verification packages - CSR
echo "Compiling CSR verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none +incdir+$ROOT/Design $ROOT/Verification/CSR/csr_reg_block_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_reg_checker_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/CSR/csr_top.sv

# Verification packages - Execute stage
echo "Compiling Execute verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Execute/execute_top.sv

# Verification packages - Memory stage
echo "Compiling Memory verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_flat_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_reg_block_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_ral_checker_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Memory/mem_top.sv

# Verification packages - WriteBack stage
echo "Compiling WriteBack verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/WriteBack/writeback_top.sv

# Verification packages - Hazard
echo "Compiling Hazard verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_item_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_config_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_driver_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_monitor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_seq_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_agent_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_scoreboard_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_subscriber_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_predictor_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_env_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Hazard/hazard_top.sv

# Verification packages - Risc (full processor)
echo "Compiling Risc full processor verification..."
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/commit_checker.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/csr_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/decode_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/execute_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/fetch_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/flp_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/hazard_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/memory_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/wb_wr.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/risc_interface.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/risc_test_pkg.sv
vlog -work work +define+XLEN=$XLEN -vopt -stats=none $ROOT/Verification/Risc/risc_top.sv

echo "Compiling complete!"
