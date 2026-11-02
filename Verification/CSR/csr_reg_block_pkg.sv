// =============================================================================
// csr_reg_block_pkg.sv
// -----------------------------------------------------------------------------
// UVM RAL model of the CSR state the CSR file stores.
//
// csr_file keeps each CSR as explicit registers (no CSR array), so every RAL
// register is built from the fields that have storage, each with its own
// backdoor path. Bits without storage (constant or derived: mstatus.MPP/FS/
// SD, misa, mip, the counters' live increment) are not part of the RAL; the
// predictor checks their read value through CsrOut instead.
// =============================================================================
package csr_reg_block_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    `include "../../Design/csr_defs.sv"

    class csr_reg extends uvm_reg;
        `uvm_object_utils(csr_reg)

        function new(string name = "csr_reg");
            super.new(name, FINAL_DATA_WIDTH, UVM_NO_COVERAGE);
        endfunction

        // Add one stored field and its backdoor path
        function void add_stored_field(string fname, int lsb, int size, string hdl);
            uvm_reg_field f = uvm_reg_field::type_id::create(fname);
            f.configure(this, size, lsb, "RW", 1, '0, 1, 0, 1);
            add_hdl_path_slice(hdl, lsb, size);
        endfunction
    endclass

    class csr_reg_block extends uvm_reg_block;
        `uvm_object_utils(csr_reg_block)

        csr_reg regs[csr_index_t];

        function new(string name = "csr_reg_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        function csr_reg add_csr(csr_index_t index, string name);
            regs[index] = csr_reg::type_id::create(name);
            regs[index].configure(this, null, "");
            return regs[index];
        endfunction

        virtual function void build();
            csr_reg r;
            configure(null);
            // CSR numbers are logical addresses, not byte addresses.
            default_map = create_map("default_map", 0, FINAL_DATA_WIDTH/8, UVM_LITTLE_ENDIAN, 0);
            r = add_csr(fflags,   "fflags");   r.add_stored_field("value", 0, 5, "Fflags");
            r = add_csr(frm,      "frm");      r.add_stored_field("value", 0, 3, "Frm");
            r = add_csr(mstatus,  "mstatus");  r.add_stored_field("mie", `MIE, 1, "MStatusMIE");
                                               r.add_stored_field("mpie", `MPIE, 1, "MStatusMPIE");
            r = add_csr(mie,      "mie");      r.add_stored_field("msie", `MS_I, 1, "MieMSIE");
                                               r.add_stored_field("mtie", `MT_I, 1, "MieMTIE");
                                               r.add_stored_field("meie", `ME_I, 1, "MieMEIE");
            r = add_csr(mtvec,    "mtvec");    r.add_stored_field("value", 0, FINAL_DATA_WIDTH, "Mtvec");
            r = add_csr(mscratch, "mscratch"); r.add_stored_field("value", 0, FINAL_DATA_WIDTH, "Mscratch");
            r = add_csr(mepc,     "mepc");     r.add_stored_field("value", 0, FINAL_DATA_WIDTH, "Mepc");
            r = add_csr(mcause,   "mcause");   r.add_stored_field("value", 0, FINAL_DATA_WIDTH, "Mcause");
            r = add_csr(mtval,    "mtval");    r.add_stored_field("value", 0, FINAL_DATA_WIDTH, "Mtval");
            r = add_csr(minstret, "minstret"); r.add_stored_field("value", 0, FINAL_DATA_WIDTH, $sformatf("Minstret[%0d:0]", FINAL_DATA_WIDTH-1));
            foreach(regs[i])
                default_map.add_reg(regs[i], uvm_reg_addr_t'(i), "RW");
            add_hdl_path("csr_top.DUT");
        endfunction
    endclass

endpackage:csr_reg_block_pkg
