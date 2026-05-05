package writeback_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import writeback_driver_pkg::*;
    import writeback_monitor_pkg::*;
    import writeback_config_pkg::*;
    import writeback_item_pkg::*;

    class writeback_agent extends uvm_agent;

        //Register the class into the factory
        `uvm_component_utils(writeback_agent)

        //Override the constructor function
        function new (string name = "writeback_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        writeback_driver drv;
        writeback_monitor mon;
        uvm_sequencer #(writeback_item) seq;
        writeback_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(writeback_config)::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = writeback_driver::type_id::create("drv",this);
                seq = uvm_sequencer #(writeback_item)::type_id::create("seq",this);
            end
            mon = writeback_monitor::type_id::create("mon",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv.vif = configuration.vif;
                drv.seq_item_port.connect(seq.seq_item_export);
            end
            mon.vif = configuration.vif;
        endfunction:connect_phase

    endclass:writeback_agent



endpackage: writeback_agent_pkg