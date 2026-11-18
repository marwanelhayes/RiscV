// =============================================================================
// execute_env_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage environment.
//
// Agent, coverage subscriber, predictor and scoreboard come from
// tb_base_pkg::base_env (monitor -> subscriber, predictor, scoreboard).
//
// Also builds the FPU and CSR environments in passive mode: they monitor the
// FPU and CSR file inside the execute stage through FLP_INTF and CSR_INTF.
// =============================================================================
package execute_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import execute_agent_pkg::*;
    import execute_scoreboard_pkg::*;
    import execute_subscriber_pkg::*;
    import execute_predictor_pkg::*;
    import execute_config_pkg::*;
    import flp_env_pkg::*;
    import flp_config_pkg::*;
    import csr_env_pkg::*;
    import csr_config_pkg::*;

    // =========================================================================
    // execute_env: Execute stage agent, coverage, predictor and scoreboard
    // =========================================================================
    class execute_env extends base_env #(execute_config, execute_agent, execute_scoreboard, execute_subscriber, execute_predictor);

        `uvm_component_utils(execute_env)

        function new (string name = "execute_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        flp_env    flp_environment;
        flp_config flp_configuration;
        csr_env    csr_environment;
        csr_config csr_configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            flp_configuration = flp_config::type_id::create("flp_configuration",this);
            flp_configuration.enable = UVM_PASSIVE;
            if(!uvm_config_db #(virtual flp_interface)::get(this,"","FLP_INTF",flp_configuration.vif))
                `uvm_fatal(get_type_name(),"FPU Environment couldn't receive virtual interface")
            uvm_config_db #(flp_config)::set(this,"flp_environment","CONFG",flp_configuration);
            flp_environment = flp_env::type_id::create("flp_environment",this);

            csr_configuration = csr_config::type_id::create("csr_configuration",this);
            csr_configuration.enable = UVM_PASSIVE;
            if(!uvm_config_db #(virtual csr_interface)::get(this,"","CSR_INTF",csr_configuration.vif))
                `uvm_fatal(get_type_name(),"CSR Environment couldn't receive virtual interface")
            uvm_config_db #(csr_config)::set(this,"csr_environment","CONFG",csr_configuration);
            csr_environment = csr_env::type_id::create("csr_environment",this);
        endfunction:build_phase

    endclass:execute_env

endpackage:execute_env_pkg
