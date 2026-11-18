// =============================================================================
// hazard_env_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
// =============================================================================
package hazard_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import hazard_agent_pkg::*;
    import hazard_scoreboard_pkg::*;
    import hazard_subscriber_pkg::*;
    import hazard_predictor_pkg::*;
    import hazard_config_pkg::*;

    // =========================================================================
    // hazard_env: Hazard unit agent, coverage, predictor and scoreboard
    // =========================================================================
    class hazard_env extends base_env #(hazard_config, hazard_agent, hazard_scoreboard, hazard_subscriber, hazard_predictor);

        `uvm_component_utils(hazard_env)

        function new (string name = "hazard_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

    endclass:hazard_env

endpackage:hazard_env_pkg
