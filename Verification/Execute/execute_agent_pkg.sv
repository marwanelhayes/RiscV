package execute_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import execute_driver_pkg::*;
    import execute_monitor_pkg::*;
    import execute_config_pkg::*;
    import execute_item_pkg::*;

    class execute_agent extends uvm_agent;

        //Register the class into the factory
        `uvm_component_utils(execute_agent)

        //Override the constructor function
        function new (string name = "execute_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        execute_driver drv;
        execute_monitor mon;
        uvm_sequencer #(execute_item) seq;
        execute_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(execute_config)::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = execute_driver::type_id::create("drv",this);
                seq = uvm_sequencer #(execute_item)::type_id::create("seq",this);
            end
            mon = execute_monitor::type_id::create("mon",this);
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

    endclass:execute_agent



endpackage: execute_agent_pkg