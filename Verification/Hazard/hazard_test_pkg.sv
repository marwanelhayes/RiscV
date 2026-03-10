package hazard_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import hazard_env_pkg::*;
    import hazard_seq_pkg::*;
    import hazard_config_pkg::*;

    class hazard_test extends uvm_test;

        //Register the class into the factory
        `uvm_component_utils(hazard_test)

        //Override the constructor function
        function new (string name = "hazard_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        hazard_env env;
        hazard_seq main_sequence;
        hazard_config configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual hazard_interface)::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = hazard_config::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(hazard_config)::set(this,"env","CONFG",configuration);
            env = hazard_env::type_id::create("env",this);
            main_sequence = hazard_seq::type_id::create("main_sequence",this);
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

    endclass:hazard_test




endpackage:hazard_test_pkg