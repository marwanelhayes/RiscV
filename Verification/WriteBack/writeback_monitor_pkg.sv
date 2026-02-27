package writeback_monitor_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import writeback_item_pkg::*;

    class writeback_monitor #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_monitor;

        //Register the class into the factory
        `uvm_component_param_utils(writeback_monitor #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "writeback_monitor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(writeback_item #(DATA_WIDTH,ADDR_WIDTH)) mon_port;
        writeback_item #(DATA_WIDTH,  ADDR_WIDTH) mon_item;
        virtual writeback_interface #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port",this);
            mon_item = writeback_item #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("mon_item");
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

    endclass:writeback_monitor


endpackage: writeback_monitor_pkg