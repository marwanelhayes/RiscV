# =============================================================================
# sim_fetch.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Fetch stage verification
# Usage: do sim_fetch.do
# =============================================================================

# Compile design and verification (if not already compiled)
do C:/marwan-ahmed/Work/RiscV/Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work fetch_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/fetch_top/clk
add wave sim:/fetch_top/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/fetch_top/uut/PCF
add wave sim:/fetch_top/uut/StallD
add wave sim:/fetch_top/uut/FlushD

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/fetch_top/uut/PCPlus4D
add wave sim:/fetch_top/uut/InstructionD
add wave sim:/fetch_top/uut/PCPlus4F

# Pipeline register signals
add wave -noupdate -divider {Pipeline Registers}
add wave sim:/fetch_top/uut/PCPlus4D
add wave sim:/fetch_top/uut/InstructionD

# Internal signals
add wave -noupdate -divider {Internal}
add wave sim:/fetch_top/uut/InstructionF
add wave sim:/fetch_top/uut/PCPlus4F

# Run simulation
run -all

echo "Simulation complete!"