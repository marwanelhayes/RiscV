// =============================================================================
// writeback_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// UVM Cookbook in-order comparator scoreboard for the Write-back stage.
// Reference model lives in writeback_predictor_pkg.
//
//   - Two uvm_tlm_analysis_fifo's absorb arrival-order skew between the
//     predictor (expected stream) and the monitor (actual stream).
//   - run_phase get()s one transaction from each FIFO and compares them using
//     uvm_object::compare(), which dispatches to writeback_item::do_compare.
//   - reset_phase flushes both FIFOs so transactions captured before a reset
//     are not paired with post-reset transactions.
// =============================================================================
package writeback_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import writeback_item_pkg::*;

    class writeback_scoreboard extends uvm_scoreboard;

        //Register the class to the factory
        `uvm_component_utils(writeback_scoreboard)

        //Override the constructor function
        function new (string name = "writeback_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        // In-order comparator FIFOs
        uvm_tlm_analysis_fifo #(writeback_item) actual_fifo;
        uvm_tlm_analysis_fifo #(writeback_item) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        // ── Cookbook in-order comparator ─────────────────────────────────────
        virtual task run_phase (uvm_phase phase);
            writeback_item act;
            writeback_item exp;
            forever
            begin
                actual_fifo.get(act);
                expected_fifo.get(exp);
                check_one(act, exp);
            end
        endtask:run_phase

        // Flush both FIFOs on reset so stale items do not cross the boundary.
        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            actual_fifo.flush();
            expected_fifo.flush();
        endtask:reset_phase

        // Compare actual vs expected via compare() on the sequence item.
        function void check_one (writeback_item act, writeback_item exp);
            if(!act.compare(exp))
            begin
                `uvm_error("SCB MISMATCH","Actual and expected items do not match in WriteBack stage!")
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
            `uvm_info("SCB","WRITEBACK Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Fail count = %0d",fail),UVM_MEDIUM)
        endfunction:report_phase

    endclass:writeback_scoreboard

endpackage:writeback_scoreboard_pkg
