# =============================================================================
# sim_execute.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Execute stage verification
# Usage: do ../sim_execute.do
# =============================================================================

quit -sim
do ../do/compile.do

vsim -voptargs=+acc execute_top +cover +UVM_VERBOSITY=UVM_MEDIUM +UVM_MAX_QUIT_COUNT=100


# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/execute_top/clk
add wave sim:/execute_top/DUT/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs - GPR}
add wave sim:/execute_top/DUT/RD1E
add wave sim:/execute_top/DUT/RD2E
add wave sim:/execute_top/DUT/SignImmE
add wave sim:/execute_top/DUT/ALUControlE
add wave sim:/execute_top/DUT/funct3E
add wave sim:/execute_top/DUT/BranchE
add wave sim:/execute_top/DUT/JumpE
add wave sim:/execute_top/DUT/ALUSrcE
add wave sim:/execute_top/DUT/MemWriteE

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/execute_top/DUT/ALUOutM
add wave sim:/execute_top/DUT/WriteDataM
add wave sim:/execute_top/DUT/RdM
add wave sim:/execute_top/DUT/PCSrcE
add wave sim:/execute_top/DUT/RegWriteM
add wave sim:/execute_top/DUT/SelectorM

# Forwarding signals
add wave -noupdate -divider {Forwarding}
add wave sim:/execute_top/DUT/ForwardAE
add wave sim:/execute_top/DUT/ForwardBE
add wave sim:/execute_top/DUT/SrcAE
add wave sim:/execute_top/DUT/SrcBE

# CSR signals
add wave -noupdate -divider {CSR Interface}
add wave sim:/execute_top/DUT/CsrAccessE
add wave sim:/execute_top/DUT/CsrOperationE
add wave sim:/execute_top/DUT/CsrIndexE
add wave sim:/execute_top/DUT/CsrOutM
add wave sim:/execute_top/DUT/TrapIsSet
add wave sim:/execute_top/DUT/CsrOutPC

# FPU signals
add wave -noupdate -divider {FPU Interface}
add wave sim:/execute_top/DUT/FPUValidE
add wave sim:/execute_top/DUT/FPUControlE
add wave sim:/execute_top/DUT/RoundModeE
add wave sim:/execute_top/DUT/FPUOutM
add wave sim:/execute_top/DUT/FPURegWriteM
add wave sim:/execute_top/DUT/FPUBusyM
add wave sim:/execute_top/DUT/FPUDoneM

# Run simulation
onfinish stop
run -all

# Save and report functional coverage
coverage save execute.ucdb
coverage report -detail -output execute_cov.txt
coverage report -summary

echo "Simulation complete!"