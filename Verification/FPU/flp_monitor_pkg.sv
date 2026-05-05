package flp_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import flp_item_pkg::*;

    class flp_monitor extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_utils(flp_monitor)

        //Override the constructor function
        function new (string name = "flp_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(flp_item) mon_port;
        flp_item mon_item;
        virtual flp_interface vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = flp_item::type_id::create("mon_item");
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

    endclass:flp_monitor


endpackage: flp_monitor_pkg