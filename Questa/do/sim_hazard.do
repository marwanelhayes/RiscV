# =============================================================================
# sim_hazard.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Hazard unit verification
# Usage: do sim_hazard.do
# =============================================================================

# Compile design and verification (if not already compiled)
do C:/marwan-ahmed/Work/RiscV/Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work hazard_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/hazard_top/clk

# Register indices inputs
add wave -noupdate -divider {Register Indices}
add wave sim:/hazard_top/uut/Rs1E
add wave sim:/hazard_top/uut/Rs2E
add wave sim:/hazard_top/uut/RdE
add wave sim:/hazard_top/uut/Rs1D
add wave sim:/hazard_top/uut/Rs2D
add wave sim:/hazard_top/uut/RdM
add wave sim:/hazard_top/uut/RdW

# Register write enables
add wave -noupdate -divider {Write Enables}
add wave sim:/hazard_top/uut/RegWriteM
add wave sim:/hazard_top/uut/RegWriteW
add wave sim:/hazard_top/uut/FPURegWriteM
add wave sim:/hazard_top/uut/FPURegWriteW

# Control signals
add wave -noupdate -divider {Control Signals}
add wave sim:/hazard_top/uut/SelectorE
add wave sim:/hazard_top/uut/PCSrcE
add wave sim:/hazard_top/uut/TrapIsSet

# Output signals
add wave -noupdate -divider {Hazard Outputs}
add wave sim:/hazard_top/uut/ForwardAE
add wave sim:/hazard_top/uut/ForwardBE
add wave sim:/hazard_top/uut/ForwardFloatingAE
add wave sim:/hazard_top/uut/ForwardFloatingBE
add wave sim:/hazard_top/uut/StallD
add wave sim:/hazard_top/uut/StallF
add wave sim:/hazard_top/uut/FlushE
add wave sim:/hazard_top/uut/FlushD

# Run simulation
run -all

echo "Simulation complete!"