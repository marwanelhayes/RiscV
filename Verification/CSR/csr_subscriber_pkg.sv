package csr_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import csr_item_pkg::*;

    class csr_subscriber extends uvm_subscriber #(csr_item);

        `uvm_component_utils(csr_subscriber)

        csr_item sub_item;

        covergroup cvr_grp();
            rst_cg: coverpoint sub_item.rst;
            CsrAccess_cg: coverpoint sub_item.CsrAccess iff(sub_item.rst);
            CsrOperation_cg: coverpoint sub_item.CsrOperation iff(sub_item.rst && sub_item.CsrAccess);
            CsrIndex_cg: coverpoint sub_item.CsrIndex iff(sub_item.rst && sub_item.CsrAccess);
            Traps_cg: coverpoint sub_item.Traps iff(sub_item.rst);
            mret_cg: coverpoint sub_item.mret iff(sub_item.rst);
            TimerInterrupt_cg: coverpoint sub_item.TimerInterrupt iff(sub_item.rst);
            ExternalInterrupt_cg: coverpoint sub_item.ExternalInterrupt iff(sub_item.rst);
            SoftwareInterrupt_cg: coverpoint sub_item.SoftwareInterrupt iff(sub_item.rst);
            TrapIsSet_cg: coverpoint sub_item.TrapIsSet iff(sub_item.rst);
            RoundingMode_cg: coverpoint sub_item.RoundingMode iff(sub_item.rst);
        endgroup:cvr_grp

        function new (string name = "csr_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:csr_subscriber

endpackage: csr_subscriber_pkg
