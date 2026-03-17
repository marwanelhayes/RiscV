package flp_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import flp_agent_pkg::*;
    import flp_scoreboard_pkg::*;
    import flp_subscriber_pkg::*;
    import flp_config_pkg::*;

    class flp_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(flp_env)

        //Override the constructor function
        function new (string name = "flp_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        flp_agent agent;
        flp_scoreboard scoreboard;
        flp_subscriber  sub;
        flp_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(flp_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(flp_config)::set(this,"agent","CONFG",configuration);
            agent = flp_agent::type_id::create("agent",this);
            scoreboard = flp_scoreboard::type_id::create("scoreboard",this);
            sub = flp_subscriber ::type_id::create("sub",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(scoreboard.sc_port);
            agent.mon.mon_port.connect(sub.analysis_export);
        endfunction:connect_phase

    endclass:flp_env
endpackage:flp_env_pkg