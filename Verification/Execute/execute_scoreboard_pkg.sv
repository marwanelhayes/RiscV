// =============================================================================
// execute_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// UVM Cookbook in-order comparator scoreboard for the Execute stage.
// Reference model lives in execute_predictor_pkg.
// =============================================================================
package execute_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import execute_item_pkg::*;

    class execute_scoreboard extends uvm_scoreboard;

        `uvm_component_utils(execute_scoreboard)

        function new (string name = "execute_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_tlm_analysis_fifo #(execute_item) actual_fifo;
        uvm_tlm_analysis_fifo #(execute_item) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        virtual task run_phase (uvm_phase phase);
            execute_item act, exp;
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

        function void check_one (execute_item act, execute_item exp);
            if(!act.compare(exp))
            begin
                `uvm_error("SCB MISMATCH","Actual and expected items do not match in Execute stage!")
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
            `uvm_info("SCB","EXECUTE Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Physical Fail count = %0d",fail),UVM_MEDIUM)
        endfunction:report_phase

    endclass:execute_scoreboard

endpackage:execute_scoreboard_pkg
