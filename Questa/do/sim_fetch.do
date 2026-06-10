# =============================================================================
# sim_fetch.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Fetch stage verification
# Usage: do ../sim_fetch.do
# =============================================================================

# Compile design and verification (if not already compiled)
quit -sim
do ../do/compile.do

# Load simulation
vsim -voptargs=+acc fetch_top +cover +UVM_VERBOSITY=UVM_HIGH +UVM_MAX_QUIT_COUNT=100

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/fetch_top/clk
add wave sim:/fetch_top/DUT/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/fetch_top/DUT/PCF
add wave sim:/fetch_top/DUT/StallD
add wave sim:/fetch_top/DUT/FlushD

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/fetch_top/DUT/PCPlus4D
add wave sim:/fetch_top/DUT/InstructionD
add wave sim:/fetch_top/DUT/PCPlus4F

# Pipeline register signals
add wave -noupdate -divider {Pipeline Registers}
add wave sim:/fetch_top/DUT/PCPlus4D
add wave sim:/fetch_top/DUT/InstructionD

# Internal signals
add wave -noupdate -divider {Internal}
add wave sim:/fetch_top/DUT/InstructionF
add wave sim:/fetch_top/DUT/PCPlus4F

# CACHE signals
add wave -noupdate -divider {CACHE}
add wave sim:/fetch_top/DUT/ICache/*

#Clear simulation transcript for clear message reading
catch {.main clear}

# Run simulation
onfinish stop
run -all

# Save and report functional coverage
coverage save fetch.ucdb
coverage report -detail -output fetch_cov.txt
coverage report -summary

echo "Simulation complete!"