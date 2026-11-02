# =============================================================================
# sim_risc.do
# -----------------------------------------------------------------------------
# Questa simulation do file for full RISC-V processor verification
# Usage: do ../sim_risc.do
# =============================================================================

# Compile design and verification (if not already compiled)
do ../do/compile.do

# Load simulation
vsim -voptargs=+acc -lib work risc_top +UVM_VERBOSITY=UVM_LOW

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/risc_top/clk
add wave sim:/risc_top/DUT/rst

# Interrupts
add wave -noupdate -divider {Interrupts}
add wave sim:/risc_top/DUT/ExternalInterrupt
add wave sim:/risc_top/DUT/TimerInterrupt
add wave sim:/risc_top/DUT/SoftwareInterrupt

# Fetch Stage
add wave -noupdate -divider {Fetch Stage}
add wave sim:/risc_top/DUT/Fetch/PCF
add wave sim:/risc_top/DUT/Fetch/PCPlus4F
add wave sim:/risc_top/DUT/Fetch/PCPlus4D
add wave sim:/risc_top/DUT/Fetch/InstructionD

# Decode Stage
add wave -noupdate -divider {Decode Stage}
add wave sim:/risc_top/DUT/Decode/InstructionD
add wave sim:/risc_top/DUT/Decode/PCPlus4D
add wave sim:/risc_top/DUT/Decode/Rs1D
add wave sim:/risc_top/DUT/Decode/Rs2D
add wave sim:/risc_top/DUT/Decode/RdE
add wave sim:/risc_top/DUT/Decode/RD1E
add wave sim:/risc_top/DUT/Decode/RD2E
add wave sim:/risc_top/DUT/Decode/SignImmE
add wave sim:/risc_top/DUT/Decode/ALUControlE
add wave sim:/risc_top/DUT/Decode/RegWriteE
add wave sim:/risc_top/DUT/Decode/ALUSrcE
add wave sim:/risc_top/DUT/Decode/BranchE
add wave sim:/risc_top/DUT/Decode/JumpE

# Execute Stage
add wave -noupdate -divider {Execute Stage}
add wave sim:/risc_top/DUT/Execute/ALUOutM
add wave sim:/risc_top/DUT/Execute/WriteDataM
add wave sim:/risc_top/DUT/Execute/RdM
add wave sim:/risc_top/DUT/Execute/PCSrcE
add wave sim:/risc_top/DUT/Execute/RegWriteM
add wave sim:/risc_top/DUT/Execute/SelectorM
add wave sim:/risc_top/DUT/Execute/MemWriteE
add wave sim:/risc_top/DUT/Execute/TrapIsSet

# Memory Stage
add wave -noupdate -divider {Memory Stage}
add wave sim:/risc_top/DUT/Memory/ReadDataW
add wave sim:/risc_top/DUT/Memory/RdW
add wave sim:/risc_top/DUT/Memory/RegWriteW
add wave sim:/risc_top/DUT/Memory/SelectorW
add wave sim:/risc_top/DUT/Memory/ALUOutW

# Write-back Stage
add wave -noupdate -divider {Write-back Stage}
add wave sim:/risc_top/DUT/WriteBack/ResultW
add wave sim:/risc_top/DUT/WriteBack/PCF

# Hazard Unit
add wave -noupdate -divider {Hazard Unit}
add wave sim:/risc_top/DUT/Hazard/StallD
add wave sim:/risc_top/DUT/Hazard/StallF
add wave sim:/risc_top/DUT/Hazard/FlushE
add wave sim:/risc_top/DUT/Hazard/FlushD
add wave sim:/risc_top/DUT/Hazard/ForwardAE
add wave sim:/risc_top/DUT/Hazard/ForwardBE

# FPU
add wave -noupdate -divider {Floating point}
add wave sim:/risc_top/DUT/Execute/FPU/valid
add wave sim:/risc_top/DUT/Execute/FPU/InA
add wave sim:/risc_top/DUT/Execute/FPU/InB
add wave sim:/risc_top/DUT/Execute/FPU/operation
add wave sim:/risc_top/DUT/Execute/FPU/round_mode
add wave sim:/risc_top/DUT/Execute/FPU/RdF
add wave sim:/risc_top/DUT/Execute/FPU/MoveOperation
add wave sim:/risc_top/DUT/Execute/FPU/RegWrite
add wave sim:/risc_top/DUT/Execute/FPU/Result
add wave sim:/risc_top/DUT/Execute/FPU/RdFOut
add wave sim:/risc_top/DUT/Execute/FPU/RegWriteOut
add wave sim:/risc_top/DUT/Execute/FPU/MoveOperationOut
add wave sim:/risc_top/DUT/Execute/FPU/busy
add wave sim:/risc_top/DUT/Execute/FPU/done
add wave sim:/risc_top/DUT/Execute/FPU/Overflow
add wave sim:/risc_top/DUT/Execute/FPU/Underflow
add wave sim:/risc_top/DUT/Execute/FPU/NaN
add wave sim:/risc_top/DUT/Execute/FPU/Inf
add wave sim:/risc_top/DUT/Execute/FPU/Zero
add wave sim:/risc_top/DUT/Execute/FPU/InvalidDiv

# CSR
add wave -noupdate -divider {CSR}
add wave sim:/risc_top/DUT/Execute/CSR/CsrOperation
add wave sim:/risc_top/DUT/Execute/CSR/Traps
add wave sim:/risc_top/DUT/Execute/CSR/mret
add wave sim:/risc_top/DUT/Execute/CSR/PC
add wave sim:/risc_top/DUT/Execute/CSR/Address
add wave sim:/risc_top/DUT/Execute/CSR/CsrAccess
add wave sim:/risc_top/DUT/Execute/CSR/CsrIn
add wave sim:/risc_top/DUT/Execute/CSR/CsrIndex
add wave sim:/risc_top/DUT/Execute/CSR/TimerInterrupt
add wave sim:/risc_top/DUT/Execute/CSR/ExternalInterrupt
add wave sim:/risc_top/DUT/Execute/CSR/SoftwareInterrupt
add wave sim:/risc_top/DUT/Execute/CSR/CsrOutPC
add wave sim:/risc_top/DUT/Execute/CSR/CsrOut
add wave sim:/risc_top/DUT/Execute/CSR/TrapIsSet
add wave sim:/risc_top/DUT/Execute/CSR/RoundingMode

# Run simulation
run -all

echo "Simulation complete!"