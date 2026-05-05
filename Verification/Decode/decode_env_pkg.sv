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
    import decode_config_pkg::*;

    class decode_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(decode_env)

        //Override the constructor function
        function new (string name = "decode_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        decode_agent agent;
        decode_scoreboard scoreboard;
        decode_subscriber  sub;
        decode_config configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(decode_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(decode_config)::set(this,"agent","CONFG",configuration);
            agent = decode_agent::type_id::create("agent",this);
            scoreboard = decode_scoreboard::type_id::create("scoreboard",this);
            sub = decode_subscriber ::type_id::create("sub",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(scoreboard.sc_port);
            agent.mon.mon_port.connect(sub.analysis_export);
        endfunction:connect_phase

    endclass:decode_env
endpackage:decode_env_pkg