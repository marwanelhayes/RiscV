package execute_env_pkg;
    
    //Importing uvm classes
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import execute_agent_pkg::*;
    import execute_scoreboard_pkg::*;
    import execute_subscriber_pkg::*;
    import execute_predictor_pkg::*;
    import execute_config_pkg::*;
    import flp_env_pkg::*;
    import flp_config_pkg::*;
    import csr_env_pkg::*;
    import csr_config_pkg::*;

    class execute_env extends uvm_env;

        //Register the class into the factory
        `uvm_component_utils(execute_env)

        //Override the constructor function
        function new (string name = "execute_env", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        execute_agent       agent;
        execute_scoreboard  scoreboard;
        execute_subscriber  sub;
        execute_predictor   predictor;
        execute_config      configuration;
        flp_env flp_environment;
        flp_config flp_configuration;
        csr_env csr_environment;
        csr_config csr_configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(! uvm_config_db #(execute_config)::get(this,"","CONFG",configuration))
                `uvm_error("ENV","Environment couldn't receive configuration object")
            uvm_config_db #(execute_config)::set(this,"agent","CONFG",configuration);
            agent      = execute_agent     ::type_id::create("agent",this);
            scoreboard = execute_scoreboard::type_id::create("scoreboard",this);
            sub        = execute_subscriber::type_id::create("sub",this);
            predictor  = execute_predictor ::type_id::create("predictor",this);
            flp_configuration = flp_config::type_id::create("flp_configuration",this);
            flp_configuration.enable = UVM_PASSIVE;
            if(! uvm_config_db #(virtual flp_interface)::get(this,"","FLP_INTF",flp_configuration.vif))
                    `uvm_error("ENV","FPU Environment couldn't receive virtual interface")
            uvm_config_db #(flp_config)::set(this,"flp_environment","CONFG",flp_configuration);
            flp_environment = flp_env::type_id::create("flp_environment",this);

            csr_configuration = csr_config::type_id::create("csr_configuration",this);
            csr_configuration.enable = UVM_PASSIVE;
            if(! uvm_config_db #(virtual csr_interface)::get(this,"","CSR_INTF",csr_configuration.vif))
                    `uvm_error("ENV","CSR Environment couldn't receive virtual interface")
            uvm_config_db #(csr_config)::set(this,"csr_environment","CONFG",csr_configuration);
            csr_environment = csr_env::type_id::create("csr_environment",this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            // Monitor feeds the coverage subscriber, the predictor, and the
            // actual-side FIFO of the scoreboard (Cookbook in-order pattern).
            agent.mon.mon_port.connect(sub.analysis_export);
            agent.mon.mon_port.connect(predictor.analysis_export);
            agent.mon.mon_port.connect(scoreboard.actual_fifo.analysis_export);
            // Predictor publishes expected transactions to the scoreboard.
            predictor.exp_port.connect(scoreboard.expected_fifo.analysis_export);
        endfunction:connect_phase

    endclass:execute_env
endpackage:execute_env_pkg
