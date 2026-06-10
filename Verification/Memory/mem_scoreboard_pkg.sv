// =============================================================================
// mem_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage scoreboard package for UVM verification.
//
// Reference model now lives in mem_predictor_pkg (emit-before-update +
// single-cycle golden memory). This scoreboard is the UVM Cookbook in-order
// comparator:
//   - Two uvm_tlm_analysis_fifo's absorb arrival-order skew between the
//     predictor (expected stream) and the monitor (actual stream).
//   - run_phase get()s one transaction from each FIFO and compares them with
//     uvm_object::compare(), which dispatches to mem_item::do_compare (the *W
//     fields).
//   - reset_phase flushes both FIFOs so transactions captured before a reset
//     are not paired with post-reset transactions.
// =============================================================================
package mem_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_item_pkg::*;

    class mem_scoreboard extends uvm_scoreboard;

        //Register the class to the factory
        `uvm_component_utils(mem_scoreboard)

        //Override the constructor function
        function new (string name = "mem_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        // In-order comparator FIFOs
        uvm_tlm_analysis_fifo #(mem_item) actual_fifo;
        uvm_tlm_analysis_fifo #(mem_item) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        // ── Cookbook in-order comparator ─────────────────────────────────────
        virtual task run_phase (uvm_phase phase);
            mem_item act;
            mem_item exp;
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

        // Compare actual vs expected via mem_item::do_compare (the *W fields).
        function void check_one (mem_item act, mem_item exp);
            if(!act.compare(exp))
            begin
                `uvm_error("SCB MISMATCH","Actual and expected items do not match in Memory stage!")
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
            `uvm_info("SCB","MEMORY Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction:report_phase

    endclass:mem_scoreboard

endpackage:mem_scoreboard_pkg
