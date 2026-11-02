// =============================================================================
// decode_reg_checker_pkg.sv
// -----------------------------------------------------------------------------
// Cross-checks the RAL mirror against actual DUT register memory over the
// backdoor HDL path.
//   Continuous : each negedge, peek the register just written (RdW / RdFW) and
//                compare to its mirror. The mirror was updated by the predictor
//                at the prior posedge, so it aligns with the DUT negedge commit.
//   Final      : do_final_sweep() backdoor-peeks and compares every register;
//                called by the test after the stimulus objection body.
// =============================================================================
package decode_reg_checker_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import decode_reg_block_pkg::*;

    class decode_reg_checker extends uvm_component;
        `uvm_component_utils(decode_reg_checker)

        decode_reg_block          reg_block;
        virtual decode_interface  vif;

        int cont_success, cont_fail;

        function new(string name = "decode_reg_checker", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(decode_reg_block)::get(this,"","REG_BLOCK",reg_block))
                `uvm_fatal("REGCHK","reg_checker couldn't receive reg_block")
            if(!uvm_config_db #(virtual decode_interface)::get(this,"","INTF",vif))
                `uvm_fatal("REGCHK","reg_checker couldn't receive interface")
        endfunction

        // Backdoor-compare one register to its mirror. peek() is blocking -> task.
        // Returns ok=1 on match; emits a uvm_error and returns ok=0 on mismatch.
        // Counting is left to the caller so the same path serves both the
        // continuous watcher and the final sweep.
        // NOTE: capture the mirror BEFORE peek(). peek() auto-predicts the mirror
        // to the value it reads, which would otherwise mask a real mismatch.
        task compare_reg(uvm_reg r, string kind, output bit ok);
            uvm_reg_data_t hw, mir;
            uvm_status_e   status;
            mir = r.get_mirrored_value();    // predictor's expected value (pre-peek)
            r.peek(status, hw);              // backdoor read of DUT memory
            void'(r.predict(mir, .kind(UVM_PREDICT_DIRECT))); // undo peek's auto-predict
            ok = 1'b0;
            if(status != UVM_IS_OK)
                `uvm_error("REGCHK",$sformatf("%s %s backdoor peek failed", kind, r.get_name()))
            else if(hw[31:0] !== mir[31:0])
                `uvm_error("REGCHK",$sformatf("%s %s mismatch: DUT=0x%08h mirror=0x%08h",
                    kind, r.get_name(), hw[31:0], mir[31:0]))
            else
                ok = 1'b1;
        endtask

        virtual task run_phase(uvm_phase phase);
            fork
                continuous_watch();
            join_none
        endtask

        task continuous_watch();
            bit ok;
            forever begin
                @(negedge vif.clk);
                if(vif.rst) begin   // rst is active-low; rst==1 means running
                    // x0 included: the mirror pins x0 to 0, so a write that
                    // lands in DUT x0 is reported.
                    if(vif.RegWriteW) begin
                        compare_reg(reg_block.gpr_rf.regs[int'(vif.RdW)], "GPR", ok);
                        if(ok) cont_success++; else cont_fail++;
                    end
                    if(vif.FPURegWriteW) begin
                        compare_reg(reg_block.fpr_rf.regs[int'(vif.RdFW)], "FPR", ok);
                        if(ok) cont_success++; else cont_fail++;
                    end
                end
            end
        endtask

        // Public: called by the test after the stimulus objection body.
        // Uses the same backdoor peek+compare path so the reported count
        // reflects actual value mismatches (not just backdoor access status).
        task do_final_sweep();
            bit ok;
            int fin_fail = 0;
            // Drain: let the last driven write-backs propagate through the
            // monitor -> predictor mirror update and the DUT negedge commit
            // before sampling, so the sweep is deterministic (not a race).
            repeat(3) @(posedge vif.clk);
            foreach(reg_block.gpr_rf.regs[i]) begin
                compare_reg(reg_block.gpr_rf.regs[i], "GPR", ok);
                if(!ok) fin_fail++;
            end
            foreach(reg_block.fpr_rf.regs[i]) begin
                compare_reg(reg_block.fpr_rf.regs[i], "FPR", ok);
                if(!ok) fin_fail++;
            end
            if(fin_fail != 0)
                `uvm_error("REGCHK",$sformatf("Final backdoor sweep: %0d register(s) mismatched", fin_fail))
            else
                `uvm_info("REGCHK","Final backdoor sweep: all 64 registers match mirror",UVM_LOW)
        endtask

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("REGCHK",$sformatf("Continuous backdoor: success=%0d fail=%0d",
                cont_success, cont_fail),UVM_LOW)
        endfunction

    endclass:decode_reg_checker

endpackage:decode_reg_checker_pkg
