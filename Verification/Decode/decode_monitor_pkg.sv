package decode_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import decode_item_pkg::*;

    class decode_monitor extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_utils(decode_monitor)

        //Override the constructor function
        function new (string name = "decode_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(decode_item) mon_port;
        decode_item mon_item, cloned_item;
        virtual decode_interface vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = decode_item::type_id::create("mon_item");
        endfunction:build_phase

        virtual task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever
            begin:monitoring
                vif.intf2mon(mon_item);
                if(!$cast(cloned_item, mon_item.clone()))
                    `uvm_fatal("CLONE_FAIL","Failed to clone the monitor item")
                mon_port.write(cloned_item);
                `uvm_info("MON",cloned_item.convert2str,UVM_HIGH)
            end:monitoring
        endtask:run_phase

    endclass:decode_monitor


endpackage: decode_monitor_pkg