// =============================================================================
// decode_reg_block_pkg.sv
// -----------------------------------------------------------------------------
// UVM RAL block for the Decode stage: holds the GPR and FPR register files.
// No real bus exists (datapath reg files), so the default map's addresses are
// nominal and access is backdoor-only. HDL root is the DUT instance.
// =============================================================================
package decode_reg_block_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import decode_gpr_reg_pkg::*;
    import decode_fpr_reg_pkg::*;

    class decode_reg_block extends uvm_reg_block;
        `uvm_object_utils(decode_reg_block)

        gpr_reg_file gpr_rf;
        fpr_reg_file fpr_rf;

        function new(string name = "decode_reg_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            configure(null);   // standard block registration (no bus parent)
            default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);

            gpr_rf = gpr_reg_file::type_id::create("gpr_rf");
            gpr_rf.build(this, default_map);

            fpr_rf = fpr_reg_file::type_id::create("fpr_rf");
            fpr_rf.build(this, default_map);

            // Backdoor root: the decode_stage DUT instance in decode_top.
            add_hdl_path("decode_top.DUT");
        endfunction
    endclass

endpackage:decode_reg_block_pkg
