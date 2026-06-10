# =============================================================================
# sim_fpu.do
# -----------------------------------------------------------------------------
# Questa simulation do file for FPU verification
# Usage: do ../sim_fpu.do
# =============================================================================

# Compile design and verification (if not already compiled)
quit -sim
do ../do/compile.do

# Load simulation
# -----------------------------------------------------------------------------
# Reference-model selection:
#   - SystemVerilog tasks (default): just run this do-file.
#   - DPI-C Python golden: build the lib first
#         cd ../../Verification/FPU/dpi && make
#     then add +FLP_DPI to the vsim plusargs below.
# The DPI shared library is loaded automatically when it exists; FLP_DPI_DIR
# tells the embedded Python where to find fpu_golden.py.
set flp_dpi_dir [file normalize ../../Verification/FPU/dpi]
if {[file exists $flp_dpi_dir/libfpu_ref.so]} {
    setenv FLP_DPI_DIR $flp_dpi_dir
    vsim -voptargs=+acc flp_top +cover +UVM_VERBOSITY=UVM_MEDIUM +UVM_MAX_QUIT_COUNT=100 \
        -sv_lib $flp_dpi_dir/libfpu_ref
} else {
    vsim -voptargs=+acc flp_top +cover +UVM_VERBOSITY=UVM_MEDIUM +UVM_MAX_QUIT_COUNT=100
}

# Add signals to wave
echo "Adding signals to waveform..."

# Main clock and reset
add wave -noupdate -divider {Clock and Reset}
add wave sim:/flp_top/clk
add wave sim:/flp_top/DUT/rst

# DUT input signals
add wave -noupdate -divider {DUT Inputs}
add wave sim:/flp_top/DUT/valid
add wave sim:/flp_top/DUT/InA
add wave sim:/flp_top/DUT/InB
add wave sim:/flp_top/DUT/operation
add wave sim:/flp_top/DUT/round_mode
add wave sim:/flp_top/DUT/RdF
add wave sim:/flp_top/DUT/MoveOperation
add wave sim:/flp_top/DUT/RegWrite

# DUT output signals
add wave -noupdate -divider {DUT Outputs}
add wave sim:/flp_top/DUT/Result
add wave sim:/flp_top/DUT/RdFOut
add wave sim:/flp_top/DUT/RegWriteOut
add wave sim:/flp_top/DUT/MoveOperationOut
add wave sim:/flp_top/DUT/busy
add wave sim:/flp_top/DUT/done

# Status flags
add wave -noupdate -divider {Status Flags}
add wave sim:/flp_top/DUT/Overflow
add wave sim:/flp_top/DUT/Underflow
add wave sim:/flp_top/DUT/NaN
add wave sim:/flp_top/DUT/Inf
add wave sim:/flp_top/DUT/Zero
add wave sim:/flp_top/DUT/InvalidDiv

# FPU Internal Signals
add wave -noupdate -divider {FPU signals}
add wave sim:/flp_top/DUT/*

# Clear simulation transcript for clear message reading
catch {.main clear}

# Run simulation
onfinish stop
run -all

# Save and report functional coverage
coverage save fpu.ucdb
coverage report -detail -output fpu_cov.txt
coverage report -summary

echo "Simulation complete!"
