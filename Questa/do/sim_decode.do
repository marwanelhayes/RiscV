# =============================================================================
# sim_decode.do
# -----------------------------------------------------------------------------
# Questa simulation do file for Decode stage verification
# Usage: do ../sim_decode.do
# =============================================================================

quit -sim
do ../do/compile.do

vsim -voptargs=+acc decode_top +cover +UVM_VERBOSITY=UVM_MEDIUM +UVM_MAX_QUIT_COUNT=100

echo "Adding signals to waveform..."

add wave -noupdate -divider {Clock and Reset}
add wave sim:/decode_top/clk
add wave sim:/decode_top/DUT/rst

add wave -noupdate -divider {DUT Inputs}
add wave sim:/decode_top/DUT/PCPlus4D
add wave sim:/decode_top/DUT/InstructionD
add wave sim:/decode_top/DUT/FlushE
add wave sim:/decode_top/DUT/RegWriteW
add wave sim:/decode_top/DUT/ResultW
add wave sim:/decode_top/DUT/RdW
add wave sim:/decode_top/DUT/FPURegWriteW
add wave sim:/decode_top/DUT/FPUOutW
add wave sim:/decode_top/DUT/RdFW
add wave sim:/decode_top/DUT/MoveOperationW

add wave -noupdate -divider {DUT Outputs}
add wave sim:/decode_top/DUT/Rs1E
add wave sim:/decode_top/DUT/Rs2E
add wave sim:/decode_top/DUT/RdE
add wave sim:/decode_top/DUT/RD1E
add wave sim:/decode_top/DUT/RD2E
add wave sim:/decode_top/DUT/SignImmE
add wave sim:/decode_top/DUT/ALUControlE
add wave sim:/decode_top/DUT/SelectorE
add wave sim:/decode_top/DUT/RegWriteE
add wave sim:/decode_top/DUT/MemWriteE
add wave sim:/decode_top/DUT/BranchE
add wave sim:/decode_top/DUT/JumpE
add wave sim:/decode_top/DUT/CsrAccessE
add wave sim:/decode_top/DUT/CsrIndexE
add wave sim:/decode_top/DUT/CsrOperationE
add wave sim:/decode_top/DUT/EcallE
add wave sim:/decode_top/DUT/EbreakE
add wave sim:/decode_top/DUT/MRetE
add wave sim:/decode_top/DUT/IllegaleInstructionE

add wave -noupdate -divider {FPU Outputs}
add wave sim:/decode_top/DUT/RdFE
add wave sim:/decode_top/DUT/RD1FE
add wave sim:/decode_top/DUT/RD2FE
add wave sim:/decode_top/DUT/FPUControlE
add wave sim:/decode_top/DUT/RoundModeE
add wave sim:/decode_top/DUT/FPURegWriteE
add wave sim:/decode_top/DUT/MoveOperationE
add wave sim:/decode_top/DUT/FPUValidE

# Clear simulation transcript for clear message reading
catch {.main clear}

onfinish stop
run -all

# Save and report functional coverage
coverage save decode.ucdb
coverage report -detail -output decode_cov.txt
coverage report -summary

echo "Simulation complete!"
