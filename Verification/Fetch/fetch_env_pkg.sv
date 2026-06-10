// =============================================================================
// fetch_env_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage environment package for UVM verification.
// =============================================================================
package fetch_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import fetch_agent_pkg::*;
    import fetch_scoreboard_pkg::*;
    import fetch_subscriber_pkg::*;
    import fetch_predictor_pkg::*;
    import fetch_config_pkg::*;

    class fetch_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(fetch_env)

        //Override the constructor function
        function new (string name = "fetch_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        fetch_agent agent;
        fetch_scoreboard scoreboard;
        fetch_subscriber  sub;
        fetch_predictor   predictor;
        fetch_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(fetch_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(fetch_config)::set(this,"agent","CONFG",configuration);
            agent      = fetch_agent     ::type_id::create("agent",this);
            scoreboard = fetch_scoreboard::type_id::create("scoreboard",this);
            sub        = fetch_subscriber::type_id::create("sub",this);
            predictor  = fetch_predictor ::type_id::create("predictor",this);
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

    endclass:fetch_env
endpackage:fetch_env_pkg