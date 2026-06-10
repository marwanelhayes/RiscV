// =============================================================================
// decode_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// UVM Cookbook in-order comparator scoreboard for the Decode stage.
// Reference model lives in decode_predictor_pkg (emit-before-update on the
// shadow integer/FP register files).
// =============================================================================
package decode_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import decode_item_pkg::*;

    class decode_scoreboard extends uvm_scoreboard;

        `uvm_component_utils(decode_scoreboard)

        function new (string name = "decode_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_tlm_analysis_fifo #(decode_item) actual_fifo;
        uvm_tlm_analysis_fifo #(decode_item) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        virtual task run_phase (uvm_phase phase);
            decode_item act, exp;
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

        function void check_one (decode_item act, decode_item exp);
            if(!act.compare(exp))
            begin
                `uvm_error("SCB MISMATCH","Actual and expected items do not match in Decode stage!")
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
            `uvm_info("SCB","DECODE Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Fail count = %0d",fail),UVM_MEDIUM)
        endfunction:report_phase

    endclass:decode_scoreboard

endpackage:decode_scoreboard_pkg
