// Continuously checks the CSR RAL mirror against the DUT through backdoor paths.
package csr_reg_checker_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import csr_reg_block_pkg::*;

    class csr_reg_checker extends uvm_component;
        `uvm_component_utils(csr_reg_checker)

        csr_reg_block         reg_block;
        virtual csr_interface vif;
        int success;
        int fail;

        function new(string name = "csr_reg_checker", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(csr_reg_block)::get(this, "", "REG_BLOCK", reg_block))
                `uvm_fatal("CSR_RAL", "checker could not receive register block")
            if(!uvm_config_db #(virtual csr_interface)::get(this, "", "INTF", vif))
                `uvm_fatal("CSR_RAL", "checker could not receive interface")
        endfunction

        task compare_reg(csr_reg r, string check_name, output bit ok);
            uvm_reg_data_t expected;
            uvm_reg_data_t actual;
            uvm_status_e status;

            expected = r.get_mirrored_value();
            r.peek(status, actual);
            // peek() auto-predicts; restore the independent expected mirror.
            void'(r.predict(expected, .kind(UVM_PREDICT_DIRECT)));
            ok = (status == UVM_IS_OK) && (actual[FINAL_DATA_WIDTH-1:0] === expected[FINAL_DATA_WIDTH-1:0]);
            if(!ok)
                `uvm_error("CSR_RAL", $sformatf(
                    "%s %s mismatch: DUT=0x%0h mirror=0x%0h status=%s",
                    check_name, r.get_name(), actual[FINAL_DATA_WIDTH-1:0], expected[FINAL_DATA_WIDTH-1:0],
                    status.name()))
        endtask

        task check_all(string check_name, output int failures);
            csr_index_t index;
            bit ok;

            failures = 0;
            foreach(reg_block.regs[index]) begin
                compare_reg(reg_block.regs[index], check_name, ok);
                if(ok)
                    success++;
                else begin
                    fail++;
                    failures++;
                end
            end
        endtask

        virtual task run_phase(uvm_phase phase);
            int failures;
            // ponytail: 11 peeks/cycle is intentionally simple; select only
            // touched CSRs if this becomes a measured simulation bottleneck.
            forever begin
                @(negedge vif.clk);
                if(vif.rst)
                    check_all("continuous", failures);
            end
        endtask

        task do_final_sweep();
            int failures;
            repeat(2) @(negedge vif.clk);
            check_all("final", failures);
            if(failures == 0)
                `uvm_info("CSR_RAL", "final backdoor sweep: all CSRs match", UVM_LOW)
        endtask

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("CSR_RAL", $sformatf(
                "backdoor checks: success=%0d fail=%0d", success, fail), UVM_LOW)
        endfunction
    endclass

endpackage:csr_reg_checker_pkg
