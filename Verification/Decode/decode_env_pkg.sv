// =============================================================================
// decode_env_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
//
// Adds the GPR/FPR register model (RAL) shared by the predictor and the reg
// checker, which compares the model with the DUT register files by backdoor.
// =============================================================================
package decode_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import decode_agent_pkg::*;
    import decode_scoreboard_pkg::*;
    import decode_subscriber_pkg::*;
    import decode_predictor_pkg::*;
    import decode_config_pkg::*;
    import decode_reg_block_pkg::*;
    import decode_reg_checker_pkg::*;

    // =========================================================================
    // decode_env: Decode stage agent, coverage, predictor and scoreboard
    // =========================================================================
    class decode_env extends base_env #(decode_config, decode_agent, decode_scoreboard, decode_subscriber, decode_predictor);

        `uvm_component_utils(decode_env)

        function new (string name = "decode_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        decode_reg_block   reg_block;
        decode_reg_checker reg_checker;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            reg_block = decode_reg_block::type_id::create("decode_reg_block");
            reg_block.build();
            reg_block.lock_model();
            uvm_config_db #(decode_reg_block)::set(this,"predictor","REG_BLOCK",reg_block);
            uvm_config_db #(decode_reg_block)::set(this,"reg_checker","REG_BLOCK",reg_block);
            reg_checker = decode_reg_checker::type_id::create("reg_checker",this);
        endfunction:build_phase

    endclass:decode_env

endpackage:decode_env_pkg
