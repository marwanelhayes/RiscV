// =============================================================================
// fetch_env_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
//
// Adds the instruction-memory register model (RAL) and a checker that compares
// the DUT instruction memory with the program image by backdoor.
// =============================================================================
package fetch_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import fetch_agent_pkg::*;
    import fetch_scoreboard_pkg::*;
    import fetch_subscriber_pkg::*;
    import fetch_predictor_pkg::*;
    import fetch_config_pkg::*;
    import fetch_reg_block_pkg::*;
    import fetch_mem_checker_pkg::*;

    // =========================================================================
    // fetch_env: Fetch stage agent, coverage, predictor and scoreboard
    // =========================================================================
    class fetch_env extends base_env #(fetch_config, fetch_agent, fetch_scoreboard, fetch_subscriber, fetch_predictor);

        `uvm_component_utils(fetch_env)

        function new (string name = "fetch_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        fetch_reg_block   reg_block;
        fetch_mem_checker mem_checker;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            reg_block = fetch_reg_block::type_id::create("fetch_reg_block");
            reg_block.build();
            reg_block.lock_model();
            uvm_config_db #(fetch_reg_block)::set(this, "mem_checker", "REG_BLOCK", reg_block);
            mem_checker = fetch_mem_checker::type_id::create("mem_checker",this);
        endfunction:build_phase

    endclass:fetch_env

endpackage:fetch_env_pkg
