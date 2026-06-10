// =============================================================================
// flp_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// UVM Cookbook in-order comparator scoreboard for the FPU.
//   - Two uvm_tlm_analysis_fifo's absorb arrival-order skew between the
//     predictor (expected stream) and the monitor (actual stream).
//   - The reference model lives in flp_predictor_pkg (emit-before-update).
//   - Numeric comparison uses a 5% relative tolerance to absorb the rounding
//     differences between the bit-accurate DUT and the shortreal reference.
//     Exact equality is enforced on enum / status / register-write fields.
// =============================================================================
package flp_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import flp_item_pkg::*;

    class flp_scoreboard extends uvm_scoreboard;

        `uvm_component_utils(flp_scoreboard)

        function new (string name = "flp_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_tlm_analysis_fifo #(flp_item) actual_fifo;
        uvm_tlm_analysis_fifo #(flp_item) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        virtual task run_phase (uvm_phase phase);
            flp_item act, exp;
            forever
            begin
                actual_fifo.get(act);
                expected_fifo.get(exp);
                check_one(act, exp);
            end
        endtask:run_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            actual_fifo.flush();
            expected_fifo.flush();
        endtask:reset_phase

        // ── In-order pair comparison (Cookbook pattern) ──────────────────────
        function void check_one (flp_item act, flp_item exp);
            if(!act.compare(exp))
            begin
                `uvm_error("SCB MISMATCH","Actual and expected items do not match in FPU stage!")
                `uvm_info("SCB MISMATCH",{"\n\t\t",exp.convert2str()},UVM_MEDIUM)
                fail++;
            end
            else
            begin
                success++;
            end
        endfunction:check_one

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","FPU Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Fail count = %0d",fail),UVM_MEDIUM)
        endfunction:report_phase

    endclass:flp_scoreboard

endpackage:flp_scoreboard_pkg
