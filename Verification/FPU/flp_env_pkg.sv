// =============================================================================
// flp_env_pkg.sv
// -----------------------------------------------------------------------------
// FPU environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
// =============================================================================
package flp_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import flp_agent_pkg::*;
    import flp_scoreboard_pkg::*;
    import flp_subscriber_pkg::*;
    import flp_predictor_pkg::*;
    import flp_config_pkg::*;

    // =========================================================================
    // flp_env: FPU agent, coverage, predictor and scoreboard
    // =========================================================================
    class flp_env extends base_env #(flp_config, flp_agent, flp_scoreboard, flp_subscriber, flp_predictor);

        `uvm_component_utils(flp_env)

        function new (string name = "flp_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

    endclass:flp_env

endpackage:flp_env_pkg
