package writeback_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import writeback_item_pkg::*;

    class writeback_subscriber extends uvm_subscriber #(writeback_item);

        //Register the class to the factory
        `uvm_component_utils(writeback_subscriber)


        writeback_item sub_item;

        covergroup cvr_grp();
            rst_cg: coverpoint sub_item.rst iff(!sub_item.rst);
            PCSrcE_cg: coverpoint sub_item.PCSrcE iff(!sub_item.rst);
            StallF_cg: coverpoint sub_item.StallF iff(!sub_item.rst);
            PCPlus4F_cg: coverpoint sub_item.PCPlus4F iff(!sub_item.rst);
            PCBranchE_cg: coverpoint sub_item.PCBranchE iff(!sub_item.rst);
            ALUOutW_cg: coverpoint sub_item.ALUOutW iff(!sub_item.rst);
            ReadDataW_cg: coverpoint sub_item.ReadDataW iff(!sub_item.rst);
            SelectorW_cg: coverpoint sub_item.SelectorW iff(!sub_item.rst);
            CsrOutW_cg: coverpoint sub_item.CsrOutW iff(!sub_item.rst);
            PCPlus4W_cg: coverpoint sub_item.PCPlus4W iff(!sub_item.rst);
            ResultW_cg: coverpoint sub_item.ResultW iff(!sub_item.rst);
            PCF_cg: coverpoint sub_item.PCF iff(!sub_item.rst);
            TrapIsSet_cg: coverpoint sub_item.TrapIsSet iff(!sub_item.rst);
            CsrOutPC_cg: coverpoint sub_item.CsrOutPC iff(!sub_item.rst);
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
