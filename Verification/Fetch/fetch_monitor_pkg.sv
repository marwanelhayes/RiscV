package fetch_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fetch_item_pkg::*;

    class fetch_monitor extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_utils(fetch_monitor)

        //Override the constructor function
        function new (string name = "fetch_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(fetch_item) mon_port;
        fetch_item mon_item;
        virtual fetch_interface vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = fetch_item::type_id::create("mon_item");
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

    endclass:fetch_monitor


endpackage: fetch_monitor_pkg