package mem_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import mem_agent_pkg::*;
    import mem_scoreboard_pkg::*;
    import mem_subscriber_pkg::*;
    import mem_predictor_pkg::*;
    //import mem_flat_predictor_pkg::*;
    import mem_config_pkg::*;

    class mem_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(mem_env)

        //Override the constructor function
        function new (string name = "mem_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_agent agent;
        mem_scoreboard scoreboard;
        mem_subscriber  sub;
        mem_predictor   predictor;
        mem_config configuration;
        // Architectural (flat) checker running in parallel with the structural
        // predictor above - its own predictor + scoreboard, independent stream.
        // mem_flat_predictor flat_predictor;
        // mem_scoreboard     flat_scoreboard;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(mem_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(mem_config)::set(this,"agent","CONFG",configuration);
            agent      = mem_agent     ::type_id::create("agent",this);
            scoreboard = mem_scoreboard::type_id::create("scoreboard",this);
            sub        = mem_subscriber::type_id::create("sub",this);
            predictor  = mem_predictor ::type_id::create("predictor",this);
            // flat_predictor  = mem_flat_predictor::type_id::create("flat_predictor",this);
            // flat_scoreboard = mem_scoreboard    ::type_id::create("flat_scoreboard",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            // Monitor feeds the coverage subscriber, the predictor, and the
            // actual-side FIFO of the scoreboard (Cookbook in-order pattern).
            agent.mon.mon_port.connect(sub.analysis_export);
            agent.mon.mon_port.connect(predictor.analysis_export);
            agent.mon.mon_port.connect(scoreboard.actual_fifo.analysis_export);
            // Predictor publishes expected transactions to the scoreboard.
            predictor.exp_port.connect(scoreboard.expected_fifo.analysis_export);

            // Parallel architectural checker: same monitor stream, own FIFOs.
            // agent.mon.mon_port.connect(flat_predictor.analysis_export);
            // agent.mon.mon_port.connect(flat_scoreboard.actual_fifo.analysis_export);
            // flat_predictor.exp_port.connect(flat_scoreboard.expected_fifo.analysis_export);
        endfunction:connect_phase

    endclass:mem_env
endpackage:mem_env_pkg