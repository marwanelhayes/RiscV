// =============================================================================
// hazard_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit scoreboard package for UVM verification.
//
// UVM Cookbook in-order comparator pattern (mirrors fetch / decode / execute):
//   - Two uvm_tlm_analysis_fifo's absorb arrival-order skew between the
//     predictor (expected stream) and the monitor (actual stream).
//   - main_phase get()s one transaction from each FIFO and compares them
//     using uvm_object::compare(), which dispatches to hazard_item::do_compare.
//
// hazard_unit is purely combinational so no reset_phase FIFO flush is needed
// (no async reset path on the DUT and no shadow state to invalidate).
// Reference model lives in hazard_predictor_pkg.
// =============================================================================
package hazard_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import hazard_item_pkg::*;

    class hazard_scoreboard extends uvm_scoreboard;

        //Register the class to the factory
        `uvm_component_utils(hazard_scoreboard)

        //Override the constructor function
        function new (string name = "hazard_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        // In-order comparator FIFOs
        uvm_tlm_analysis_fifo #(hazard_item) actual_fifo;
        uvm_tlm_analysis_fifo #(hazard_item) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        // ── Cookbook in-order comparator ─────────────────────────────────────
        virtual task run_phase (uvm_phase phase);
            hazard_item act;
            hazard_item exp;
            forever
            begin
                actual_fifo.get(act);
                expected_fifo.get(exp);
                check_one(act, exp);
            end
        endtask:run_phase

        // Compare actual vs expected via do_compare on the sequence item.
        function void check_one (hazard_item act, hazard_item exp);
            if(!act.compare(exp))
            begin
                `uvm_error("SCB MISMATCH","Actual and expected items do not match in Hazard stage!")
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
            `uvm_info("SCB","HAZARD Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Fail count = %0d",fail),UVM_MEDIUM)
        endfunction:report_phase

    endclass:hazard_scoreboard

endpackage:hazard_scoreboard_pkg
