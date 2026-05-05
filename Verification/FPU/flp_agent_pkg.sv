package flp_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import flp_driver_pkg::*;
    import flp_monitor_pkg::*;
    import flp_config_pkg::*;
    import flp_item_pkg::*;

    class flp_agent extends uvm_agent;

        //Register the class into the factory
        `uvm_component_utils(flp_agent)

        //Override the constructor function
        function new (string name = "flp_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        flp_driver drv;
        flp_monitor mon;
        uvm_sequencer #(flp_item) seq;
        flp_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(flp_config)::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = flp_driver::type_id::create("drv",this);
                seq = uvm_sequencer #(flp_item)::type_id::create("seq",this);
            end
            mon = flp_monitor::type_id::create("mon",this);
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

    endclass:flp_agent



endpackage: flp_agent_pkg