# =============================================================================
# sim_writeback.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Write-back stage verification
# Usage: do ../sim_writeback.do
# =============================================================================

# Compile design and verification (if not already compiled)
quit -sim
do ../do/compile.do

# Load simulation
vsim -voptargs=+acc writeback_top +cover +UVM_VERBOSITY=UVM_HIGH +UVM_MAX_QUIT_COUNT=100

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/writeback_top/clk
add wave sim:/writeback_top/DUT/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/writeback_top/DUT/PCSrcE
add wave sim:/writeback_top/DUT/StallF
add wave sim:/writeback_top/DUT/PCPlus4F
add wave sim:/writeback_top/DUT/PCBranchE
add wave sim:/writeback_top/DUT/ALUOutW
add wave sim:/writeback_top/DUT/ReadDataW
add wave sim:/writeback_top/DUT/SelectorW

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/writeback_top/DUT/ResultW
add wave sim:/writeback_top/DUT/PCF

# Run simulation
onfinish stop
run -all

# Save and report functional coverage
coverage save writeback.ucdb
coverage report -detail -output writeback_cov.txt
coverage report -summary

echo "Simulation complete!"