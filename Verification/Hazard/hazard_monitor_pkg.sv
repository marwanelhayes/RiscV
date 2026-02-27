package hazard_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import hazard_item_pkg::*;

    class hazard_monitor #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_param_utils(hazard_monitor #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "hazard_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(hazard_item #(DATA_WIDTH,ADDR_WIDTH)) mon_port;
        hazard_item #(DATA_WIDTH,  ADDR_WIDTH) mon_item;
        virtual hazard_interface #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = hazard_item #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("mon_item");
        endfunction:build_phase
        
        virtual task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever
            begin:monitoring
                vif.intf2mon(mon_item);
                `uvm_info("MON",mon_item.convert2str,UVM_DEBUG)
                mon_port.write(mon_item);
            end:monitoring
        
        endtask:run_phase

    endclass:hazard_monitor


endpackage: hazard_monitor_pkg