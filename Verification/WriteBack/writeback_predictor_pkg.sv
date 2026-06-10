// =============================================================================
// writeback_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Write-back stage.
//
// DUT decoupling:
//   - ResultW is combinational (always_comb on SelectorW) in wb_stage - emit
//     from the current monitored inputs every call.
//   - PCF is registered (always_ff @posedge clk or negedge rst) - shadow it
//     and use emit-before-update so the expected value matches the DUT's
//     post-posedge PCF the monitor sampled this cycle.
//   - Asynchronous active-low rst forces PCF to 0 immediately, so when
//     t.rst == 0 the shadow is flushed and the reset value is emitted in the
//     SAME cycle (rst is the only signal allowed to "update before emit").
//
// MCOW (Manual Copy On Write):
//   A single persistent expected item (exp) is reused every cycle. It is
//   populated from the current inputs (do_copy), then the combinational and
//   shadowed outputs are written onto it, and finally a clone (exp_clone) is
//   published so the scoreboard FIFO never aliases the mutating exp object.
// =============================================================================
package writeback_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import writeback_item_pkg::*;

    class writeback_predictor extends uvm_subscriber #(writeback_item);

        `uvm_component_utils(writeback_predictor)

        function new (string name = "writeback_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(writeback_item) exp_port;
        writeback_item exp, exp_clone, shadow_inputs;

        // ── PCF pipeline-register shadow ─────────────────────────────────────
        logic [FINAL_ADDR_WIDTH-1:0] q_PCF;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = writeback_item::type_id::create("exp");
            reset_shadow();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_shadow();
        endtask:reset_phase

        function void reset_shadow();
            q_PCF = '0;
        endfunction:reset_shadow

        // Combinational ResultW path - mirror wb_stage's always_comb on
        // SelectorW. Computed every cycle straight off the current inputs.
        function automatic logic [FINAL_DATA_WIDTH-1:0] compute_result(writeback_item t);
            case(t.SelectorW)
                ALUToReg: compute_result = t.ALUOutW;   // ALU result
                MemToReg: compute_result = t.ReadDataW; // Memory read data
                CSRToReg: compute_result = t.CsrOutW;   // CSR read data
                PCToReg : compute_result = t.PCPlus4W;  // PC + 4
                default : compute_result = '0;
            endcase
        endfunction:compute_result

        // Advance PCF shadow with this cycle's inputs - this is the value the
        // DUT will latch at the next posedge and the monitor will sample then.
        function void update_shadow(writeback_item t);
            if(t.TrapIsSet)
                q_PCF = t.CsrOutPC;
            else if(!t.StallF)
            begin
                if(t.PCSrcE)
                    q_PCF = t.PCBranchE;
                else
                    q_PCF = t.PCPlus4F;
            end
        endfunction:update_shadow

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (writeback_item t);
            // Async active-low rst clears registered PCF immediately.
            if(!t.rst)
                reset_shadow();

            // ResultW is combinational - compute every call from current inputs.
            exp.ResultW = compute_result(t);

            // Emit the PCF the DUT registered at the most recent posedge
            // (= current monitored PCF output).
            exp.PCF = q_PCF;

            if(!(shadow_inputs == null))
                exp.copy_inputs(shadow_inputs);

            // Clone before publishing so the FIFO never holds the mutating exp.
            if(!$cast(exp_clone, exp))
                `uvm_fatal("WB_PRED", "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);

            // Update PCF shadow from this cycle's inputs - that value will be
            // latched into PCF at the next posedge and emitted then.
            if(t.rst)
                update_shadow(t);
            if(!$cast(shadow_inputs, t))
                `uvm_fatal("WB_PRED", "Failed to copy inputs to shadow - check for non-cloneable fields")
        endfunction:write

    endclass:writeback_predictor

endpackage:writeback_predictor_pkg
