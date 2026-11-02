// =============================================================================
// flp_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the FPU.
//
// Implements the emit-before-update sequential reference pattern so its output
// transaction is published in lockstep with the registered DUT outputs the
// monitor sampled this cycle. The transaction received from the monitor is
// already aligned to the FPU's done pulse (intf2mon waits for done), so for
// each incoming item the predictor:
//   1. Emits the previously-computed shadow values that match the current
//      registered DUT outputs.
//   2. Recomputes the reference and updates the shadow for the next cycle.
//
// Combinational status flags (NaN / Inf / Zero / Overflow / Underflow /
// InvalidDiv) follow the same shadow path because the DUT registers them
// alongside Result.
// =============================================================================
package flp_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import flp_item_pkg::*;
    import flp_ref_pkg::*;

    // ── DPI-C reference model (implemented in dpi/fpu_ref.c, Python-backed) ──
    // Only used when the predictor runs in DPI mode (+FLP_DPI). In SystemVerilog
    // mode these are never called, so the shared library does not need to be
    // loaded. Build the library with:  cd Verification/FPU/dpi && make
    import "DPI-C" context function void fpu_ref_init();
    import "DPI-C" context function void fpu_ref_shutdown();
    import "DPI-C" context function void fpu_ref_compute(
        input  int        operation,
        input  int        round_mode,
        input  int        InA_bits,
        input  int        InB_bits,
        output int        Result_bits,
        output byte       Overflow,
        output byte       Underflow,
        output byte       NaN,
        output byte       Inf,
        output byte       Zero,
        output byte       InvalidDiv
    );

    class flp_predictor extends uvm_subscriber #(flp_item);

        `uvm_component_utils(flp_predictor)

        function new (string name = "flp_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(flp_item) exp_port;
        flp_item exp, exp_clone;

        // Reference-model selector. 0 = SystemVerilog tasks (default), 1 = DPI-C
        // Python golden. Set by the +FLP_DPI plusarg or a config_db override.
        bit use_dpi = 1'b0;

        // ── Shadow registers (emit-before-update) ────────────────────────────
        logic                            q_Overflow;
        logic                            q_Underflow;
        logic                            q_NaN;
        logic                            q_Inf;
        logic                            q_Zero;
        logic                            q_InvalidDiv;
        logic [FINAL_FLP_WIDTH-1:0]      q_Result;
        fpr_t                            q_RdFOut;
        logic                            q_RegWriteOut;
        move_operation_t                 q_MoveOperationOut;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = flp_item::type_id::create("exp");
            // Select the reference model: +FLP_DPI -> Python golden via DPI-C,
            // otherwise the built-in SystemVerilog tasks. A config_db boolean
            // ("USE_DPI") can also force it on/off programmatically.
            if($test$plusargs("FLP_DPI"))
                use_dpi = 1'b1;
            void'(uvm_config_db #(bit)::get(this,"","USE_DPI",use_dpi));
            if(use_dpi)
            begin
                `uvm_info("FLP_PRED","Reference model: DPI-C Python golden (fpu_golden.py)",UVM_LOW)
                fpu_ref_init();
            end
            else
                `uvm_info("FLP_PRED","Reference model: SystemVerilog tasks",UVM_LOW)
            reset_shadow();
        endfunction:build_phase

        virtual function void final_phase (uvm_phase phase);
            super.final_phase(phase);
            if(use_dpi) fpu_ref_shutdown();
        endfunction:final_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_shadow();
        endtask:reset_phase

        function void reset_shadow();
            q_Overflow         = 1'b0;
            q_Underflow        = 1'b0;
            q_NaN              = 1'b0;
            q_Inf              = 1'b0;
            q_Zero             = 1'b0;
            q_InvalidDiv       = 1'b0;
            q_Result           = '0;
            q_RdFOut           = f0;
            q_RegWriteOut      = 1'b0;
            q_MoveOperationOut = FPUToFPU;
        endfunction:reset_shadow

        // ── SystemVerilog reference (shared with the full-core ISS) ──────────
        // The numeric Result and status flags come from flp_ref_pkg; the
        // register/move plumbing is a straight passthrough.
        function automatic void compute(
            input  flp_item t,
            output logic                            n_Overflow,
            output logic                            n_Underflow,
            output logic                            n_NaN,
            output logic                            n_Inf,
            output logic                            n_Zero,
            output logic                            n_InvalidDiv,
            output logic [FINAL_FLP_WIDTH-1:0]      n_Result,
            output fpr_t                            n_RdFOut,
            output logic                            n_RegWriteOut,
            output move_operation_t                 n_MoveOperationOut
        );
            flp_ref_compute(t.operation, t.round_mode, t.InA, t.InB,
                            n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero,
                            n_InvalidDiv, n_Result);
            n_RdFOut           = t.RdF;
            n_RegWriteOut      = t.RegWrite;
            n_MoveOperationOut = t.MoveOperation;
        endfunction:compute

        // ── DPI-C reference: identical output set, computed by fpu_golden.py ──
        // The register/move plumbing (RdFOut/RegWriteOut/MoveOperationOut) is a
        // straight passthrough exactly as in the SystemVerilog path; only the
        // numeric Result and status flags come from the Python golden model.
        function automatic void compute_dpi(
            input  flp_item t,
            output logic                            n_Overflow,
            output logic                            n_Underflow,
            output logic                            n_NaN,
            output logic                            n_Inf,
            output logic                            n_Zero,
            output logic                            n_InvalidDiv,
            output logic [FINAL_FLP_WIDTH-1:0]      n_Result,
            output fpr_t                            n_RdFOut,
            output logic                            n_RegWriteOut,
            output move_operation_t                 n_MoveOperationOut
        );
            int  d_Result_bits;
            byte d_Overflow, d_Underflow, d_NaN, d_Inf, d_Zero, d_InvalidDiv;
            fpu_ref_compute(
                int'(t.operation),
                int'(t.round_mode),
                int'(t.InA),
                int'(t.InB),
                d_Result_bits,
                d_Overflow, d_Underflow, d_NaN, d_Inf, d_Zero, d_InvalidDiv
            );
            n_Result           = d_Result_bits[FINAL_FLP_WIDTH-1:0];
            n_Overflow         = d_Overflow[0];
            n_Underflow        = d_Underflow[0];
            n_NaN              = d_NaN[0];
            n_Inf              = d_Inf[0];
            n_Zero             = d_Zero[0];
            n_InvalidDiv       = d_InvalidDiv[0];
            n_RdFOut           = t.RdF;
            n_RegWriteOut      = t.RegWrite;
            n_MoveOperationOut = t.MoveOperation;
        endfunction:compute_dpi

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (flp_item t);
            logic                            n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero, n_InvalidDiv;
            logic [FINAL_FLP_WIDTH-1:0]      n_Result;
            fpr_t                            n_RdFOut;
            logic                            n_RegWriteOut;
            move_operation_t                 n_MoveOperationOut;


            if(!t.rst)
            begin
                exp.Overflow         = 1'b0;
                exp.Underflow        = 1'b0;
                exp.NaN              = 1'b0;
                exp.Inf              = 1'b0;
                exp.Zero             = 1'b0;
                exp.InvalidDiv       = 1'b0;
                exp.Result           = '0;
                exp.RdFOut           = f0;
                exp.RegWriteOut      = 1'b0;
                exp.MoveOperationOut = FPUToFPU;
                exp.copy_inputs(t);
            end
            else if(!t.valid)
            begin
                exp.Overflow         = q_Overflow;
                exp.Underflow        = q_Underflow;
                exp.NaN              = q_NaN;
                exp.Inf              = q_Inf;
                exp.Zero             = q_Zero;
                exp.InvalidDiv       = q_InvalidDiv;
                exp.Result           = q_Result;
                exp.RdFOut           = q_RdFOut;
                exp.RegWriteOut      = q_RegWriteOut;
                exp.MoveOperationOut = q_MoveOperationOut;
            end
            else
            begin
                if(use_dpi)
                    compute_dpi(t, n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero,
                                n_InvalidDiv, n_Result, n_RdFOut, n_RegWriteOut, n_MoveOperationOut);
                else
                    compute(t, n_Overflow, n_Underflow, n_NaN, n_Inf, n_Zero,
                            n_InvalidDiv, n_Result, n_RdFOut, n_RegWriteOut, n_MoveOperationOut);
                exp.Overflow         = n_Overflow;
                exp.Underflow        = n_Underflow;
                exp.NaN              = n_NaN;
                exp.Inf              = n_Inf;
                exp.Zero             = n_Zero;
                exp.InvalidDiv       = n_InvalidDiv;
                exp.Result           = n_Result;
                exp.RdFOut           = n_RdFOut;
                exp.RegWriteOut      = n_RegWriteOut;
                exp.MoveOperationOut = n_MoveOperationOut;
                exp.copy_inputs(t);
            end
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("CLONE FAILED","Failed to clone expected item in predictor!")
            else
                exp_port.write(exp_clone);

            if(!t.rst)
            begin 
                reset_shadow();
            end
            else if(t.valid && t.done)
            begin
                q_Overflow         = exp.Overflow;
                q_Underflow        = exp.Underflow;
                q_NaN              = exp.NaN;
                q_Inf              = exp.Inf;
                q_Zero             = exp.Zero;
                q_InvalidDiv       = exp.InvalidDiv;
                q_Result           = exp.Result;
                q_RdFOut           = exp.RdFOut;
                q_RegWriteOut      = exp.RegWriteOut;
                q_MoveOperationOut = exp.MoveOperationOut;
            end
        endfunction:write

    endclass:flp_predictor

endpackage: flp_predictor_pkg
