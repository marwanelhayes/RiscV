// =============================================================================
// fetch_agent_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage agent package for UVM verification.
// =============================================================================
package fetch_agent_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import fetch_driver_pkg::*;
    import fetch_monitor_pkg::*;
    import fetch_config_pkg::*;
    import fetch_item_pkg::*;

    class fetch_agent extends uvm_agent;

        //Register the class into the factory
        `uvm_component_utils(fetch_agent)

        //Override the constructor function
        function new (string name = "fetch_agent", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        fetch_driver drv;
        fetch_monitor mon;
        uvm_sequencer #(fetch_item) seq;
        fetch_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(fetch_config)::get(this,"","CONFG",configuration))
                `uvm_error("AGT","Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = fetch_driver::type_id::create("drv",this);
                seq = uvm_sequencer #(fetch_item)::type_id::create("seq",this);
            end
            mon = fetch_monitor::type_id::create("mon",this);
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

    endclass:fetch_agent



endpackage: fetch_agent_pkg