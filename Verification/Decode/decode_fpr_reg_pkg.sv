// =============================================================================
// decode_fpr_reg_pkg.sv
// -----------------------------------------------------------------------------
// UVM RAL model of the floating-point (FPR) register file: fp_reg_file
// (DUT.FPRF). 32 x 32-bit registers f0..f31, flat storage mem[i], so the
// backdoor path for register i is a single 32-bit slice: FPRF.mem[i].
// f0 is NOT hardwired to zero in the DUT, so it is modeled as a plain RW reg.
// =============================================================================
package decode_fpr_reg_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ── Single FP register: one 32-bit RW field "value" ──────────────────────
    class fpr_reg extends uvm_reg;
        `uvm_object_utils(fpr_reg)

        rand uvm_reg_field value;

        function new(string name = "fpr_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            value = uvm_reg_field::type_id::create("value");
            value.configure(this, 32, 0, "RW", 1, 32'h0, 1, 1, 1);
        endfunction
    endclass

    // ── FPR register file: 32 fpr_reg + flat backdoor slice ──────────────────
    class fpr_reg_file extends uvm_reg_file;
        `uvm_object_utils(fpr_reg_file)

        fpr_reg regs[32];

        function new(string name = "fpr_reg_file");
            super.new(name);
        endfunction

        virtual function void build(uvm_reg_block parent, uvm_reg_map map);
            configure(parent, null, "FPRF");   // configure() registers hdl_path "FPRF"
            foreach (regs[i]) begin
                regs[i] = fpr_reg::type_id::create($sformatf("fpr%0d", i));
                regs[i].configure(parent, this, "");
                regs[i].build();
                regs[i].add_hdl_path_slice($sformatf("mem[%0d]", i), 0, 32);
                // Nominal offset past the 32 GPR regs so GPR/FPR don't collide
                // in the shared default_map (access is backdoor-only anyway).
                map.add_reg(regs[i], 32*4 + i*4, "RW");
            end
        endfunction
    endclass

endpackage:decode_fpr_reg_pkg
