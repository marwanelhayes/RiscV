# =============================================================================
# sim_mem.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Memory stage verification
# Usage: do ../sim_mem.do
# =============================================================================

# Compile design and verification (if not already compiled)
quit -sim
do ../do/compile.do

# Load simulation
vsim -voptargs=+acc mem_top +cover +UVM_VERBOSITY=UVM_HIGH +UVM_MAX_QUIT_COUNT=100

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/mem_top/clk
add wave sim:/mem_top/DUT/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/mem_top/DUT/ALUOutM
add wave sim:/mem_top/DUT/WriteDataM
add wave sim:/mem_top/DUT/funct3M
add wave sim:/mem_top/DUT/RegWriteM
add wave sim:/mem_top/DUT/SelectorM
add wave sim:/mem_top/DUT/MemWriteM

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/mem_top/DUT/ReadDataW
add wave sim:/mem_top/DUT/RdW
add wave sim:/mem_top/DUT/RegWriteW
add wave sim:/mem_top/DUT/SelectorW
add wave sim:/mem_top/DUT/ALUOutW

# Cache response / internal
add wave -noupdate -divider {Cache}
add wave sim:/mem_top/DUT/CacheHitM
add wave sim:/mem_top/DUT/ReadDataM
add wave sim:/mem_top/DUT/DCache/*

# AXI stream (DUT master <-> data_memory slave)
add wave -noupdate -divider {AXI}
add wave sim:/mem_top/axi_intf/*

# Data memory slave
add wave -noupdate -divider {Data Memory Slave}
add wave sim:/mem_top/DataMem/*

#Clear simulation transcript for clear message reading
catch {.main clear}

# Run simulation
onfinish stop
run -all

# Save and report functional coverage
coverage save mem.ucdb
coverage report -detail -output mem_cov.txt
coverage report -summary

echo "Simulation complete!"
