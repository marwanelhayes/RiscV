package mem_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import mem_driver_pkg::*;
    import mem_monitor_pkg::*;
    import mem_config_pkg::*;
    import mem_item_pkg::*;

    class mem_agent extends uvm_agent;

        //Register the class into the factory
        `uvm_component_utils(mem_agent)

        //Override the constructor function
        function new (string name = "mem_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_driver drv;
        mem_monitor mon;
        uvm_sequencer #(mem_item) seq;
        mem_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(mem_config)::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = mem_driver::type_id::create("drv",this);
                seq = uvm_sequencer #(mem_item)::type_id::create("seq",this);
            end
            mon = mem_monitor::type_id::create("mon",this);
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

    endclass:mem_agent



endpackage: mem_agent_pkg