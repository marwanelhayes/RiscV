package hazard_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import hazard_agent_pkg::*;
    import hazard_scoreboard_pkg::*;
    import hazard_subscriber_pkg::*;
    import hazard_config_pkg::*;

    class hazard_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(hazard_env)

        //Override the constructor function
        function new (string name = "hazard_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        hazard_agent agent;
        hazard_scoreboard scoreboard;
        hazard_subscriber  sub;
        hazard_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(hazard_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(hazard_config)::set(this,"agent","CONFG",configuration);
            agent = hazard_agent::type_id::create("agent",this);
            scoreboard = hazard_scoreboard::type_id::create("scoreboard",this);
            sub = hazard_subscriber ::type_id::create("sub",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(scoreboard.sc_port);
            agent.mon.mon_port.connect(sub.analysis_export);
        endfunction:connect_phase

    endclass:hazard_env
endpackage:hazard_env_pkg