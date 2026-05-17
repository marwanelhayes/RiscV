# =============================================================================
# sim_risc.do
# -----------------------------------------------------------------------------
# Questa simulation do file for full RISC-V processor verification
# Usage: do ../sim_risc.do
# =============================================================================

# Compile design and verification (if not already compiled)
do Questa/do/compile.do

# Load simulation
vsim -t 1ps -voptargs=+acc -lib work risc_top

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/risc_top/clk
add wave sim:/risc_top/rst

# Interrupts
add wave -noupdate -divider {Interrupts}
add wave sim:/risc_top/ExternalInterrupt
add wave sim:/risc_top/TimerInterrupt
add wave sim:/risc_top/SoftwareInterrupt

# Fetch Stage
add wave -noupdate -divider {Fetch Stage}
add wave sim:/risc_top/uut/Fetch/PCF
add wave sim:/risc_top/uut/Fetch/PCPlus4F
add wave sim:/risc_top/uut/Fetch/PCPlus4D
add wave sim:/risc_top/uut/Fetch/InstructionD

# Decode Stage
add wave -noupdate -divider {Decode Stage}
add wave sim:/risc_top/uut/Decode/InstructionD
add wave sim:/risc_top/uut/Decode/PCPlus4D
add wave sim:/risc_top/uut/Decode/Rs1D
add wave sim:/risc_top/uut/Decode/Rs2D
add wave sim:/risc_top/uut/Decode/RdE
add wave sim:/risc_top/uut/Decode/RD1E
add wave sim:/risc_top/uut/Decode/RD2E
add wave sim:/risc_top/uut/Decode/SignImmE
add wave sim:/risc_top/uut/Decode/ALUControlE
add wave sim:/risc_top/uut/Decode/RegWriteE
add wave sim:/risc_top/uut/Decode/ALUSrcE
add wave sim:/risc_top/uut/Decode/BranchE
add wave sim:/risc_top/uut/Decode/JumpE

# Execute Stage
add wave -noupdate -divider {Execute Stage}
add wave sim:/risc_top/uut/Execute/ALUOutM
add wave sim:/risc_top/uut/Execute/WriteDataM
add wave sim:/risc_top/uut/Execute/RdM
add wave sim:/risc_top/uut/Execute/PCSrcE
add wave sim:/risc_top/uut/Execute/RegWriteM
add wave sim:/risc_top/uut/Execute/SelectorM
add wave sim:/risc_top/uut/Execute/MemWriteE
add wave sim:/risc_top/uut/Execute/TrapIsSet

# Memory Stage
add wave -noupdate -divider {Memory Stage}
add wave sim:/risc_top/uut/Memory/ReadDataW
add wave sim:/risc_top/uut/Memory/RdW
add wave sim:/risc_top/uut/Memory/RegWriteW
add wave sim:/risc_top/uut/Memory/SelectorW
add wave sim:/risc_top/uut/Memory/ALUOutW

# Write-back Stage
add wave -noupdate -divider {Write-back Stage}
add wave sim:/risc_top/uut/WriteBack/ResultW
add wave sim:/risc_top/uut/WriteBack/PCF

# Hazard Unit
add wave -noupdate -divider {Hazard Unit}
add wave sim:/risc_top/uut/Hazard/StallD
add wave sim:/risc_top/uut/Hazard/StallF
add wave sim:/risc_top/uut/Hazard/FlushE
add wave sim:/risc_top/uut/Hazard/FlushD
add wave sim:/risc_top/uut/Hazard/ForwardAE
add wave sim:/risc_top/uut/Hazard/ForwardBE

# Run simulation
run -all

echo "Simulation complete!"