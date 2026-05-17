# =============================================================================
# sim_mem.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Memory stage verification
# Usage: do ../sim_mem.do
# =============================================================================

# Compile design and verification (if not already compiled)
do Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work mem_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/mem_top/clk
add wave sim:/mem_top/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/mem_top/uut/ALUOutM
add wave sim:/mem_top/uut/WriteDataM
add wave sim:/mem_top/uut/funct3M
add wave sim:/mem_top/uut/RegWriteM
add wave sim:/mem_top/uut/SelectorM
add wave sim:/mem_top/uut/MemWriteM

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/mem_top/uut/ReadDataW
add wave sim:/mem_top/uut/RdW
add wave sim:/mem_top/uut/RegWriteW
add wave sim:/mem_top/uut/SelectorW
add wave sim:/mem_top/uut/ALUOutW

# Memory interface
add wave -noupdate -divider {Memory Interface}
add wave sim:/mem_top/uut/ReadDataM

# Run simulation
run -all

echo "Simulation complete!"