package fetch_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import fetch_env_pkg::*;
    import fetch_seq_pkg::*;
    import fetch_config_pkg::*;

    class fetch_test extends uvm_test;

        //Register the class into the factory
        `uvm_component_utils(fetch_test)

        //Override the constructor function
        function new (string name = "fetch_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        fetch_env env;
        fetch_seq main_sequence;
        fetch_config configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual fetch_interface)::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = fetch_config::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(fetch_config)::set(this,"env","CONFG",configuration);
            env = fetch_env::type_id::create("env",this);
            main_sequence = fetch_seq::type_id::create("main_sequence",this);
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

    endclass:fetch_test




endpackage:fetch_test_pkg