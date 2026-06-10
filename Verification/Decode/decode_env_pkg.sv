// =============================================================================
// decode_env_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage environment package for UVM verification.
// =============================================================================
package decode_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import decode_agent_pkg::*;
    import decode_scoreboard_pkg::*;
    import decode_subscriber_pkg::*;
    import decode_predictor_pkg::*;
    import decode_config_pkg::*;

    class decode_env extends uvm_env;

        `uvm_component_utils(decode_env)

        function new (string name = "decode_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        decode_agent       agent;
        decode_scoreboard  scoreboard;
        decode_subscriber  sub;
        decode_predictor   predictor;
        decode_config      configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(decode_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(decode_config)::set(this,"agent","CONFG",configuration);
            agent      = decode_agent     ::type_id::create("agent",this);
            scoreboard = decode_scoreboard::type_id::create("scoreboard",this);
            sub        = decode_subscriber::type_id::create("sub",this);
            predictor  = decode_predictor ::type_id::create("predictor",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(sub.analysis_export);
            agent.mon.mon_port.connect(predictor.analysis_export);
            agent.mon.mon_port.connect(scoreboard.actual_fifo.analysis_export);
            predictor.exp_port.connect(scoreboard.expected_fifo.analysis_export);
        endfunction:connect_phase

    endclass:decode_env
endpackage:decode_env_pkg