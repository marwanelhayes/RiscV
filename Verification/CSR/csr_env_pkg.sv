package csr_env_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import csr_agent_pkg::*;
    import csr_scoreboard_pkg::*;
    import csr_subscriber_pkg::*;
    import csr_config_pkg::*;

    class csr_env extends uvm_env;

        `uvm_component_utils(csr_env)

        function new (string name = "csr_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        csr_agent agent;
        csr_scoreboard scoreboard;
        csr_subscriber sub;
        csr_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(csr_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(csr_config)::set(this,"agent","CONFG",configuration);
            agent = csr_agent::type_id::create("agent",this);
            scoreboard = csr_scoreboard::type_id::create("scoreboard",this);
            sub = csr_subscriber::type_id::create("sub",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(scoreboard.sc_port);
            agent.mon.mon_port.connect(sub.analysis_export);
        endfunction:connect_phase

    endclass:csr_env
endpackage:csr_env_pkg
