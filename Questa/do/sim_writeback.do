# =============================================================================
# sim_writeback.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Write-back stage verification
# Usage: do sim_writeback.do
# =============================================================================

# Compile design and verification (if not already compiled)
do C:/marwan-ahmed/Work/RiscV/Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work writeback_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/writeback_top/clk
add wave sim:/writeback_top/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/writeback_top/uut/PCSrcE
add wave sim:/writeback_top/uut/StallF
add wave sim:/writeback_top/uut/PCPlus4F
add wave sim:/writeback_top/uut/PCBranchE
add wave sim:/writeback_top/uut/ALUOutW
add wave sim:/writeback_top/uut/ReadDataW
add wave sim:/writeback_top/uut/SelectorW

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/writeback_top/uut/ResultW
add wave sim:/writeback_top/uut/PCF

# Run simulation
run -all

echo "Simulation complete!"