# =============================================================================
# sim_csr.do
# -----------------------------------------------------------------------------
# Questa simulation do file for CSR verification
# Usage: do ../sim_csr.do
# =============================================================================

# Compile design and verification (if not already compiled)
quit -sim
do ../do/compile.do

# Load simulation
vsim -voptargs=+acc csr_top +cover +UVM_VERBOSITY=UVM_MEDIUM +UVM_MAX_QUIT_COUNT=100

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/csr_top/clk
add wave sim:/csr_top/DUT/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/csr_top/DUT/CsrOperation
add wave sim:/csr_top/DUT/Traps
add wave sim:/csr_top/DUT/mret
add wave sim:/csr_top/DUT/PC
add wave sim:/csr_top/DUT/Address
add wave sim:/csr_top/DUT/CsrAccess
add wave sim:/csr_top/DUT/CsrIn
add wave sim:/csr_top/DUT/CsrIndex

# Interrupt inputs
add wave -noupdate -divider {Interrupts}
add wave sim:/csr_top/DUT/TimerInterrupt
add wave sim:/csr_top/DUT/ExternalInterrupt
add wave sim:/csr_top/DUT/SoftwareInterrupt

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/csr_top/DUT/CsrOutPC
add wave sim:/csr_top/DUT/CsrOut
add wave sim:/csr_top/DUT/TrapIsSet
add wave sim:/csr_top/DUT/RoundingMode

# Clear simulation transcript for clear message reading
catch {.main clear}

# Run simulation
# Halt (don't exit) on $finish so coverage commands below still run in batch
onfinish stop
run -all

# Save and report functional coverage
coverage save csr.ucdb
coverage report -detail -output csr_cov.txt
coverage report -summary

echo "Simulation complete!"
