package hazard_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import hazard_agent_pkg::*;
    import hazard_scoreboard_pkg::*;
    import hazard_subscriber_pkg::*;
    import hazard_predictor_pkg::*;
    import hazard_config_pkg::*;

    class hazard_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(hazard_env)

        //Override the constructor function
        function new (string name = "hazard_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        hazard_agent       agent;
        hazard_scoreboard  scoreboard;
        hazard_subscriber  sub;
        hazard_predictor   predictor;
        hazard_config      configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(hazard_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(hazard_config)::set(this,"agent","CONFG",configuration);
            agent      = hazard_agent     ::type_id::create("agent",this);
            scoreboard = hazard_scoreboard::type_id::create("scoreboard",this);
            sub        = hazard_subscriber::type_id::create("sub",this);
            predictor  = hazard_predictor ::type_id::create("predictor",this);
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
        endfunction:connect_phase

    endclass:hazard_env
endpackage:hazard_env_pkg