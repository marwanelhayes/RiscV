package csr_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import csr_item_pkg::*;

    class csr_monitor extends uvm_monitor;

        `uvm_component_utils(csr_monitor)

        function new (string name = "csr_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(csr_item) mon_port;
        csr_item mon_item;
        virtual csr_interface vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = csr_item::type_id::create("mon_item");
        endfunction:build_phase
        
        virtual task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever
            begin:monitoring
                vif.intf2mon(mon_item);
                `uvm_info("MON",mon_item.convert2str(),UVM_DEBUG)
                mon_port.write(mon_item);
            end:monitoring
        
        endtask:run_phase

    endclass:csr_monitor

endpackage:csr_monitor_pkg
