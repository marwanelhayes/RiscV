# =============================================================================
# sim_fpu.do
# -----------------------------------------------------------------------------
# Questa simulation do file for FPU verification
# Usage: do ../sim_fpu.do
# =============================================================================

# Compile design and verification (if not already compiled)
do Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work flp_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/flp_top/clk
add wave sim:/flp_top/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/flp_top/uut/valid
add wave sim:/flp_top/uut/InA
add wave sim:/flp_top/uut/InB
add wave sim:/flp_top/uut/operation
add wave sim:/flp_top/uut/round_mode
add wave sim:/flp_top/uut/RdF
add wave sim:/flp_top/uut/MoveOperation
add wave sim:/flp_top/uut/RegWrite

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/flp_top/uut/Result
add wave sim:/flp_top/uut/RdFOut
add wave sim:/flp_top/uut/RegWriteOut
add wave sim:/flp_top/uut/busy
add wave sim:/flp_top/uut/done

# Status flags
add wave -noupdate -divider {Status Flags}
add wave sim:/flp_top/uut/Overflow
add wave sim:/flp_top/uut/Underflow
add wave sim:/flp_top/uut/NaN
add wave sim:/flp_top/uut/Inf
add wave sim:/flp_top/uut/Zero
add wave sim:/flp_top/uut/InvalidDiv

# Run simulation
run -all

echo "Simulation complete!"