package hazard_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import hazard_item_pkg::*;

    class hazard_subscriber #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_subscriber #(hazard_item #(DATA_WIDTH,ADDR_WIDTH));

        //Register the class to the factory
        `uvm_component_param_utils(hazard_subscriber #(DATA_WIDTH,ADDR_WIDTH))


        hazard_item #(DATA_WIDTH,ADDR_WIDTH) sub_item;

        covergroup cvr_grp();
            
            Rs1E_cfg : coverpoint sub_item.Rs1E;
            Rs2E_cfg : coverpoint sub_item.Rs2E;
            RdE_cfg : coverpoint sub_item.RdE;
            Rs1D_cfg : coverpoint sub_item.Rs1D; 
            Rs2D_cfg : coverpoint sub_item.Rs2D; 
            RdM_cfg : coverpoint sub_item.RdM;
            RdW_cfg : coverpoint sub_item.RdW;
            RegWriteM_cfg : coverpoint sub_item.RegWriteM;
            RegWriteW_cfg : coverpoint sub_item.RegWriteW;
            SelectorE_cfg : coverpoint sub_item.SelectorE;
            PCSrcE_cfg : coverpoint sub_item.PCSrcE; 
            TrapIsSet_cfg : coverpoint sub_item.TrapIsSet;

            ForwardAE_cfg : coverpoint sub_item.ForwardAE;
            ForwardBE_cfg : coverpoint sub_item.ForwardBE;
            StallD_cfg : coverpoint sub_item.StallD;
            StallF_cfg : coverpoint sub_item.StallF;
            FlushE_cfg : coverpoint sub_item.FlushE;
            FlushD_cfg : coverpoint sub_item.FlushD; 
        endgroup:cvr_grp

        function new (string name = "hazard_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:hazard_subscriber

endpackage: hazard_subscriber_pkg
