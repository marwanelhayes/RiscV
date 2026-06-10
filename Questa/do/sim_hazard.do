# =============================================================================
# sim_hazard.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Hazard unit verification
# Usage: do ../sim_hazard.do
# =============================================================================

# Compile design and verification (if not already compiled)
quit -sim
do ../do/compile.do

# Load simulation
vsim -voptargs=+acc hazard_top +cover +UVM_VERBOSITY=UVM_HIGH +UVM_MAX_QUIT_COUNT=100

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/hazard_top/clk

# Register indices inputs
add wave -noupdate -divider {Register Indices}
add wave sim:/hazard_top/DUT/Rs1E
add wave sim:/hazard_top/DUT/Rs2E
add wave sim:/hazard_top/DUT/RdE
add wave sim:/hazard_top/DUT/Rs1D
add wave sim:/hazard_top/DUT/Rs2D
add wave sim:/hazard_top/DUT/RdM
add wave sim:/hazard_top/DUT/RdW

# Register write enables
add wave -noupdate -divider {Write Enables}
add wave sim:/hazard_top/DUT/RegWriteM
add wave sim:/hazard_top/DUT/RegWriteW
add wave sim:/hazard_top/DUT/FPURegWriteM
add wave sim:/hazard_top/DUT/FPURegWriteW

# Control signals
add wave -noupdate -divider {Control Signals}
add wave sim:/hazard_top/DUT/SelectorE
add wave sim:/hazard_top/DUT/PCSrcE
add wave sim:/hazard_top/DUT/TrapIsSet
add wave sim:/hazard_top/DUT/ICacheHit
add wave sim:/hazard_top/DUT/DCacheHit

# Output signals
add wave -noupdate -divider {Hazard Outputs}
add wave sim:/hazard_top/DUT/ForwardAE
add wave sim:/hazard_top/DUT/ForwardBE
add wave sim:/hazard_top/DUT/ForwardFloatingAE
add wave sim:/hazard_top/DUT/ForwardFloatingBE
add wave sim:/hazard_top/DUT/StallD
add wave sim:/hazard_top/DUT/StallF
add wave sim:/hazard_top/DUT/FlushE
add wave sim:/hazard_top/DUT/FlushD

# Run simulation
onfinish stop
run -all

# Save and report functional coverage
coverage save hazard.ucdb
coverage report -detail -output hazard_cov.txt
coverage report -summary

echo "Simulation complete!"