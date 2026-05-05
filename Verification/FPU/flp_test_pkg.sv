package flp_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import flp_env_pkg::*;
    import flp_seq_pkg::*;
    import flp_config_pkg::*;

    class flp_test extends uvm_test;

        //Register the class into the factory
        `uvm_component_utils(flp_test)

        //Override the constructor function
        function new (string name = "flp_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        flp_env env;
        flp_seq main_sequence;
        flp_config configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual flp_interface)::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = flp_config ::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(flp_config )::set(this,"env","CONFG",configuration);
            env = flp_env ::type_id::create("env",this);
            main_sequence = flp_seq ::type_id::create("main_sequence",this);
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

    endclass:flp_test




endpackage:flp_test_pkg