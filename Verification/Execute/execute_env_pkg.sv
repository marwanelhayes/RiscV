package execute_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import execute_agent_pkg::*;
    import execute_scoreboard_pkg::*;
    import execute_subscriber_pkg::*;
    import execute_config_pkg::*;

    class execute_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(execute_env)

        //Override the constructor function
        function new (string name = "execute_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        execute_agent agent;
        execute_scoreboard scoreboard;
        execute_subscriber  sub;
        execute_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(execute_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(execute_config)::set(this,"agent","CONFG",configuration);
            agent = execute_agent::type_id::create("agent",this);
            scoreboard = execute_scoreboard::type_id::create("scoreboard",this);
            sub = execute_subscriber ::type_id::create("sub",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(scoreboard.sc_port);
            agent.mon.mon_port.connect(sub.analysis_export);
        endfunction:connect_phase

    endclass:execute_env
endpackage:execute_env_pkg