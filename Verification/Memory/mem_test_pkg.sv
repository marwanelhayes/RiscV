package mem_test_pkg;
    `include "parameters_mem.svh"
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

        mem_env #(`DATA_WIDTH,`ADDR_WIDTH) env;
        mem_seq #(`DATA_WIDTH,`ADDR_WIDTH) main_sequence;
        mem_config #(`DATA_WIDTH,`ADDR_WIDTH) configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual mem_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = mem_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(mem_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"env","CONFG",configuration);
            env = mem_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("env",this);
            main_sequence = mem_seq #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("main_sequence",this);
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

    endclass:mem_test




endpackage:mem_test_pkg