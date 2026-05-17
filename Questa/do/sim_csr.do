# =============================================================================
# sim_csr.do
# -----------------------------------------------------------------------------
# Questa simulation do file for CSR verification
# Usage: do ../sim_csr.do
# =============================================================================

# Compile design and verification (if not already compiled)
do Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work csr_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/csr_top/clk
add wave sim:/csr_top/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/csr_top/uut/CsrOperation
add wave sim:/csr_top/uut/Traps
add wave sim:/csr_top/uut/mret
add wave sim:/csr_top/uut/PC
add wave sim:/csr_top/uut/Address
add wave sim:/csr_top/uut/CsrAccess
add wave sim:/csr_top/uut/CsrIn
add wave sim:/csr_top/uut/CsrIndex

# Interrupt inputs
add wave -noupdate -divider {Interrupts}
add wave sim:/csr_top/uut/TimerInterrupt
add wave sim:/csr_top/uut/ExternalInterrupt
add wave sim:/csr_top/uut/SoftwareInterrupt

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/csr_top/uut/CsrOutPC
add wave sim:/csr_top/uut/CsrOut
add wave sim:/csr_top/uut/TrapIsSet
add wave sim:/csr_top/uut/RoundingMode

# Run simulation
run -all

echo "Simulation complete!"