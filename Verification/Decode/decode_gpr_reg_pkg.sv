// =============================================================================
// decode_gpr_reg_pkg.sv
// -----------------------------------------------------------------------------
// UVM RAL model of the integer (GPR) register file: risc_reg_file (DUT.RF).
// 32 x XLEN-bit registers x0..x31, stored in one risc_mem instance, so the
// backdoor path for register i is RF.M1.mem[i].
// =============================================================================
package decode_gpr_reg_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    // ── Single integer register: one XLEN-bit RW field "value" ─────────────────
    class gpr_reg extends uvm_reg;
        `uvm_object_utils(gpr_reg)

        rand uvm_reg_field value;
        string access = "RW";

        function new(string name = "gpr_reg");
            super.new(name, FINAL_DATA_WIDTH, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            value = uvm_reg_field::type_id::create("value");
            // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible)
            value.configure(this, FINAL_DATA_WIDTH, 0, access, 1, '0, 1, 1, 1);
        endfunction
    endclass

    // ── GPR register file: 32 XLEN-wide gpr_reg ─────────────────────────────
    class gpr_reg_file extends uvm_reg_file;
        `uvm_object_utils(gpr_reg_file)

        gpr_reg regs[32];

        function new(string name = "gpr_reg_file");
            super.new(name);
        endfunction

        // parent = owning block, map = block default map for offset registration
        virtual function void build(uvm_reg_block parent, uvm_reg_map map);
            configure(parent, null, "RF");   // configure() registers hdl_path "RF"
            foreach (regs[i]) begin
                regs[i] = gpr_reg::type_id::create($sformatf("gpr%0d", i));
                if(i == 0)
                    regs[i].access = "RO";
                regs[i].configure(parent, this, "");
                regs[i].build();
                // One XLEN-wide storage array (risc_reg_file.M1)
                regs[i].add_hdl_path_slice($sformatf("M1.mem[%0d]", i), 0, FINAL_DATA_WIDTH);
                map.add_reg(regs[i], i*(FINAL_DATA_WIDTH/8), (i == 0) ? "RO" : "RW");
            end
        endfunction
    endclass

endpackage:decode_gpr_reg_pkg
