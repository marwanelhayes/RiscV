// =============================================================================
// csr_env_pkg.sv
// -----------------------------------------------------------------------------
// CSR file environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
//
// Adds the CSR register model (RAL). The predictor mirrors CSR writes into it;
// when the agent is active a reg checker compares the model with the DUT.
// =============================================================================
package csr_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import csr_agent_pkg::*;
    import csr_scoreboard_pkg::*;
    import csr_subscriber_pkg::*;
    import csr_predictor_pkg::*;
    import csr_config_pkg::*;
    import csr_reg_block_pkg::*;
    import csr_reg_checker_pkg::*;

    // =========================================================================
    // csr_env: CSR file agent, coverage, predictor and scoreboard
    // =========================================================================
    class csr_env extends base_env #(csr_config, csr_agent, csr_scoreboard, csr_subscriber, csr_predictor);

        `uvm_component_utils(csr_env)

        function new (string name = "csr_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        csr_reg_block   reg_block;
        csr_reg_checker reg_checker;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            reg_block = csr_reg_block::type_id::create("csr_reg_block");
            reg_block.build();
            reg_block.lock_model();
            uvm_config_db #(csr_reg_block)::set(this,"predictor","REG_BLOCK",reg_block);
            if(configuration.enable == UVM_ACTIVE)
            begin
                uvm_config_db #(csr_reg_block)::set(this,"reg_checker","REG_BLOCK",reg_block);
                reg_checker = csr_reg_checker::type_id::create("reg_checker",this);
            end
        endfunction:build_phase

    endclass:csr_env

endpackage:csr_env_pkg
