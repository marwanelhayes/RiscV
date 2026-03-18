package csr_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import csr_driver_pkg::*;
    import csr_monitor_pkg::*;
    import csr_config_pkg::*;
    import csr_item_pkg::*;

    class csr_agent extends uvm_agent;

        `uvm_component_utils(csr_agent)

        function new (string name = "csr_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        csr_driver drv;
        csr_monitor mon;
        uvm_sequencer #(csr_item) seq;
        csr_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(csr_config)::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = csr_driver::type_id::create("drv",this);
                seq = uvm_sequencer #(csr_item)::type_id::create("seq",this);
            end
            mon = csr_monitor::type_id::create("mon",this);
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

    endclass:csr_agent

endpackage: csr_agent_pkg
