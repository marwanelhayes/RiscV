// =============================================================================
// writeback_env_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage environment package for UVM verification.
// =============================================================================
package writeback_env_pkg;

    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import writeback_agent_pkg::*;
    import writeback_scoreboard_pkg::*;
    import writeback_subscriber_pkg::*;
    import writeback_predictor_pkg::*;
    import writeback_config_pkg::*;

    class writeback_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(writeback_env)

        //Override the constructor function
        function new (string name = "writeback_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        writeback_agent      agent;
        writeback_scoreboard scoreboard;
        writeback_subscriber sub;
        writeback_predictor  predictor;
        writeback_config     configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(writeback_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(writeback_config)::set(this,"agent","CONFG",configuration);
            agent      = writeback_agent     ::type_id::create("agent",this);
            scoreboard = writeback_scoreboard::type_id::create("scoreboard",this);
            sub        = writeback_subscriber::type_id::create("sub",this);
            predictor  = writeback_predictor ::type_id::create("predictor",this);
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

    endclass:writeback_env
endpackage:writeback_env_pkg
