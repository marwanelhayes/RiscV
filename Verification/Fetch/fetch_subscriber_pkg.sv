package fetch_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fetch_item_pkg::*;

    class fetch_subscriber #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_subscriber #(fetch_item #(DATA_WIDTH,ADDR_WIDTH));

        //Register the class to the factory
        `uvm_component_param_utils(fetch_subscriber #(DATA_WIDTH,ADDR_WIDTH))


        fetch_item #(DATA_WIDTH,ADDR_WIDTH) sub_item;


        covergroup cvr_grp();
            rst_cg: coverpoint sub_item.rst;
            PCF_cg: coverpoint sub_item.PCF iff(!sub_item.rst);
            StallD_cg: coverpoint sub_item.StallD iff(!sub_item.rst);
            FlushD_cg: coverpoint sub_item.FlushD iff(!sub_item.rst);
            PCPlus4F_cg: coverpoint sub_item.PCPlus4F iff(!sub_item.rst);
            PCPlus4D_cg: coverpoint sub_item.PCPlus4D iff(!sub_item.rst);
            InstructionD_cg: coverpoint sub_item.InstructionD iff(!sub_item.rst);
        endgroup:cvr_grp

        function new (string name = "fetch_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:fetch_subscriber

endpackage: fetch_subscriber_pkg
