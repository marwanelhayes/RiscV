package mem_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import mem_agent_pkg::*;
    import mem_scoreboard_pkg::*;
    import mem_subscriber_pkg::*;
    import mem_config_pkg::*;

    class mem_env #(parameter int DATA_WIDTH = 32 , ADDR_WIDTH = 32) extends uvm_env;

        //Register the class into the factory
        `uvm_component_param_utils(mem_env #(DATA_WIDTH,ADDR_WIDTH))

        //Override the constructor function
        function new (string name = "mem_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_agent #(DATA_WIDTH,ADDR_WIDTH) agent;
        mem_scoreboard #(DATA_WIDTH,ADDR_WIDTH) scoreboard;
        mem_subscriber  #(DATA_WIDTH,ADDR_WIDTH) sub;
        mem_config #(DATA_WIDTH,ADDR_WIDTH) configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(mem_config #(DATA_WIDTH,ADDR_WIDTH))::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(mem_config #(DATA_WIDTH,ADDR_WIDTH))::set(this,"agent","CONFG",configuration);
            agent = mem_agent #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("agent",this);
            scoreboard = mem_scoreboard #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("scoreboard",this);
            sub = mem_subscriber  #(DATA_WIDTH,ADDR_WIDTH)::type_id::create("sub",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(scoreboard.sc_port);
            agent.mon.mon_port.connect(sub.analysis_export);
        endfunction:connect_phase

    endclass:mem_env
endpackage:mem_env_pkg