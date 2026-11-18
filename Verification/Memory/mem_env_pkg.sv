// =============================================================================
// mem_env_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
//
// The predictor is the flat-memory ISA model (mem_flat_predictor). Adds the
// data-memory register model (RAL) and a checker that compares it with the DUT
// data memory by backdoor.
// =============================================================================
package mem_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import mem_agent_pkg::*;
    import mem_scoreboard_pkg::*;
    import mem_subscriber_pkg::*;
    import mem_flat_predictor_pkg::*;
    import mem_config_pkg::*;
    import mem_reg_block_pkg::*;
    import mem_ral_checker_pkg::*;

    // =========================================================================
    // mem_env: Memory stage agent, coverage, predictor and scoreboard
    // =========================================================================
    class mem_env extends base_env #(mem_config, mem_agent, mem_scoreboard, mem_subscriber, mem_flat_predictor);

        `uvm_component_utils(mem_env)

        function new (string name = "mem_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_reg_block   reg_block;
        mem_ral_checker memory_checker;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            reg_block = mem_reg_block::type_id::create("mem_reg_block");
            reg_block.build();
            reg_block.lock_model();
            uvm_config_db #(mem_reg_block)::set(this, "memory_checker", "REG_BLOCK", reg_block);
            memory_checker = mem_ral_checker::type_id::create("memory_checker",this);
        endfunction:build_phase

    endclass:mem_env

endpackage:mem_env_pkg
