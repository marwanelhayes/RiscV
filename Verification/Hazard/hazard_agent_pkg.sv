package hazard_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import hazard_driver_pkg::*;
    import hazard_monitor_pkg::*;
    import hazard_config_pkg::*;
    import hazard_item_pkg::*;

    class hazard_agent #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_agent;

        //Register the class into the factory
        `uvm_component_param_utils(hazard_agent #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "hazard_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        hazard_driver #(DATA_WIDTH,ADDR_WIDTH) drv;
        hazard_monitor #(DATA_WIDTH,ADDR_WIDTH) mon;
        uvm_sequencer #(hazard_item #(DATA_WIDTH,ADDR_WIDTH)) seq;
        hazard_config #(DATA_WIDTH,ADDR_WIDTH) configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(hazard_config #(DATA_WIDTH,ADDR_WIDTH))::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = hazard_driver #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("drv",this);
                seq = uvm_sequencer #(hazard_item #(DATA_WIDTH,ADDR_WIDTH))::type_id::create("seq",this);
            end
            mon = hazard_monitor #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("mon",this);
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

    endclass:hazard_agent



endpackage: hazard_agent_pkg