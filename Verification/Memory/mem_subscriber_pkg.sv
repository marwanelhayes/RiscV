package mem_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import mem_item_pkg::*;

    class mem_subscriber #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_subscriber #(mem_item #(DATA_WIDTH,ADDR_WIDTH));

        //Register the class to the factory
        `uvm_component_param_utils(mem_subscriber #(DATA_WIDTH,ADDR_WIDTH))


        mem_item #(DATA_WIDTH,ADDR_WIDTH) sub_item;


        covergroup cvr_grp();
            rst_cg: coverpoint sub_item.rst;
            ALUOutM_cg: coverpoint sub_item.ALUOutM iff(!sub_item.rst);
            WriteDataM_cg: coverpoint sub_item.WriteDataM iff(!sub_item.rst);
            RdM_cg: coverpoint sub_item.RdM iff(!sub_item.rst);
            CsrOutM_cg: coverpoint sub_item.CsrOutM iff(!sub_item.rst);
            PCPlus4M_cg: coverpoint sub_item.PCPlus4M iff(!sub_item.rst);
            funct3M_cg: coverpoint sub_item.funct3M iff(!sub_item.rst);
            RegWriteM_cg: coverpoint sub_item.RegWriteM iff(!sub_item.rst);
            SelectorM_cg: coverpoint sub_item.SelectorM iff(!sub_item.rst);
            MemWriteM_cg: coverpoint sub_item.MemWriteM iff(!sub_item.rst);
            ReadDataW_cg: coverpoint sub_item.ReadDataW iff(!sub_item.rst);
            RdW_cg: coverpoint sub_item.RdW iff(!sub_item.rst);
            RegWriteW_cg: coverpoint sub_item.RegWriteW iff(!sub_item.rst);
            SelectorW_cg: coverpoint sub_item.SelectorW iff(!sub_item.rst);
            ALUOutW_cg: coverpoint sub_item.ALUOutW iff(!sub_item.rst);
            CsrOutW_cg: coverpoint sub_item.CsrOutW iff(!sub_item.rst);
            PCPlus4W_cg: coverpoint sub_item.PCPlus4W iff(!sub_item.rst);
        endgroup:cvr_grp

        function new (string name = "mem_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:mem_subscriber

endpackage: mem_subscriber_pkg
