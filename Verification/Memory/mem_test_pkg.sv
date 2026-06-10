package mem_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import mem_env_pkg::*;
    import mem_seq_pkg::*;
    import mem_config_pkg::*;

    class mem_test extends uvm_test;

        //Register the class into the factory
        `uvm_component_utils(mem_test)

        //Override the constructor function
        function new (string name = "mem_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_env env;
        mem_seq main_sequence;
        mem_seq_no_rst main_sequence_no_rst;
        mem_config configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual mem_interface)::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = mem_config::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(mem_config)::set(this,"env","CONFG",configuration);
            env = mem_env::type_id::create("env",this);
            main_sequence = mem_seq::type_id::create("main_sequence",this);
            main_sequence_no_rst = mem_seq_no_rst::type_id::create("main_sequence_no_rst",this);
        endfunction:build_phase

        virtual function void end_of_elaboration_phase (uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction:end_of_elaboration_phase
        
        virtual task run_phase (uvm_phase phase);
            phase.raise_objection(this);
                main_sequence.start(env.agent.seq);
                main_sequence_no_rst.start(env.agent.seq);
            phase.drop_objection(this);
        endtask:run_phase

    endclass:mem_test




endpackage:mem_test_pkg