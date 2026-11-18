// =============================================================================
// writeback_env_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
// =============================================================================
package writeback_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import writeback_agent_pkg::*;
    import writeback_scoreboard_pkg::*;
    import writeback_subscriber_pkg::*;
    import writeback_predictor_pkg::*;
    import writeback_config_pkg::*;

    // =========================================================================
    // writeback_env: Write-back stage agent, coverage, predictor and scoreboard
    // =========================================================================
    class writeback_env extends base_env #(writeback_config, writeback_agent, writeback_scoreboard, writeback_subscriber, writeback_predictor);

        `uvm_component_utils(writeback_env)

        function new (string name = "writeback_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

    endclass:writeback_env

endpackage:writeback_env_pkg
