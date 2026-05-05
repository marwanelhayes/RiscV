package execute_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import execute_item_pkg::*;

    class execute_monitor extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_utils(execute_monitor)

        //Override the constructor function
        function new (string name = "execute_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(execute_item) mon_port;
        execute_item mon_item;
        virtual execute_interface vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = execute_item::type_id::create("mon_item");
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

    endclass:execute_monitor


endpackage: execute_monitor_pkg