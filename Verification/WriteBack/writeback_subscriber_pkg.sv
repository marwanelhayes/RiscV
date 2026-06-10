package writeback_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import writeback_item_pkg::*;
    import shared_pkg::*;

    class writeback_subscriber extends uvm_subscriber #(writeback_item);

        //Register the class to the factory
        `uvm_component_utils(writeback_subscriber)


        writeback_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // Samples while out of reset. Covers the result selector, the PC-source
        // / stall / trap controls and the data busses (sign partition).
        covergroup cvr_grp();

            SelectorW_cg: coverpoint sub_item.SelectorW iff(sub_item.rst)
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }

            PCSrcE_cg: coverpoint sub_item.PCSrcE iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            StallF_cg: coverpoint sub_item.StallF iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            TrapIsSet_cg: coverpoint sub_item.TrapIsSet iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }

            // Data busses - sign partition.
            ALUOutW_cg: coverpoint sub_item.ALUOutW iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            ReadDataW_cg: coverpoint sub_item.ReadDataW iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            CsrOutW_cg: coverpoint sub_item.CsrOutW iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }

            // ── Crosses ──────────────────────────────────────────────────────
            Selector_x_Trap_cx: cross SelectorW_cg, TrapIsSet_cg;
            PCSrc_x_Stall_cx:   cross PCSrcE_cg, StallF_cg;

        endgroup:cvr_grp

        function new (string name = "writeback_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:writeback_subscriber

endpackage: writeback_subscriber_pkg
