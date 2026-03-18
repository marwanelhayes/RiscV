package csr_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import csr_env_pkg::*;
    import csr_seq_pkg::*;
    import csr_config_pkg::*;

    class csr_test extends uvm_test;

        `uvm_component_utils(csr_test)

        function new (string name = "csr_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        csr_env env;
        csr_seq main_sequence;
        csr_config configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual csr_interface)::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = csr_config::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(csr_config)::set(this,"env","CONFG",configuration);
            env = csr_env::type_id::create("env",this);
            main_sequence = csr_seq::type_id::create("main_sequence",this);
        endfunction:build_phase

        virtual function void end_of_elaboration_phase (uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction:end_of_elaboration_phase
        
        virtual task run_phase (uvm_phase phase);
            phase.raise_objection(this);
                main_sequence.start(env.agent.seq);
            phase.drop_objection(this);
        endtask:run_phase

    endclass:csr_test

endpackage:csr_test_pkg
