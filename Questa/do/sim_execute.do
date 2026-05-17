# =============================================================================
# sim_execute.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Execute stage verification
# Usage: do ../sim_execute.do
# =============================================================================

# Compile design and verification (if not already compiled)
do Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work execute_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/execute_top/clk
add wave sim:/execute_top/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs - GPR}
add wave sim:/execute_top/uut/RD1E
add wave sim:/execute_top/uut/RD2E
add wave sim:/execute_top/uut/SignImmE
add wave sim:/execute_top/uut/ALUControlE
add wave sim:/execute_top/uut/funct3E
add wave sim:/execute_top/uut/BranchE
add wave sim:/execute_top/uut/JumpE
add wave sim:/execute_top/uut/ALUSrcE
add wave sim:/execute_top/uut/MemWriteE

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/execute_top/uut/ALUOutM
add wave sim:/execute_top/uut/WriteDataM
add wave sim:/execute_top/uut/RdM
add wave sim:/execute_top/uut/PCSrcE
add wave sim:/execute_top/uut/RegWriteM
add wave sim:/execute_top/uut/SelectorM

# Forwarding signals
add wave -noupdate -divider {Forwarding}
add wave sim:/execute_top/uut/ForwardAE
add wave sim:/execute_top/uut/ForwardBE
add wave sim:/execute_top/uut/SrcAE
add wave sim:/execute_top/uut/SrcBE

# CSR signals
add wave -noupdate -divider {CSR Interface}
add wave sim:/execute_top/uut/CsrAccessE
add wave sim:/execute_top/uut/CsrOperationE
add wave sim:/execute_top/uut/CsrIndexE
add wave sim:/execute_top/uut/CsrOutM
add wave sim:/execute_top/uut/TrapIsSet
add wave sim:/execute_top/uut/CsrOutPC

# FPU signals
add wave -noupdate -divider {FPU Interface}
add wave sim:/execute_top/uut/FPUValidE
add wave sim:/execute_top/uut/FPUControlE
add wave sim:/execute_top/uut/RoundModeE
add wave sim:/execute_top/uut/FPUOutM
add wave sim:/execute_top/uut/FPURegWriteM
add wave sim:/execute_top/uut/FPUBusyM
add wave sim:/execute_top/uut/FPUDoneM

# Run simulation
run -all

echo "Simulation complete!"