package writeback_test_pkg;
    `include "parameters_wb.svh"
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import writeback_env_pkg::*;
    import writeback_seq_pkg::*;
    import writeback_config_pkg::*;

    class writeback_test extends uvm_test;

        //Register the class into the factory
        `uvm_component_utils(writeback_test)

        //Override the constructor function
        function new (string name = "writeback_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        writeback_env #(`DATA_WIDTH,`ADDR_WIDTH) env;
        writeback_seq #(`DATA_WIDTH,`ADDR_WIDTH) main_sequence;
        writeback_config #(`DATA_WIDTH,`ADDR_WIDTH) configuration;

        function void set_config_params();
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(virtual writeback_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",configuration.vif))
                `uvm_fatal("TEST","Couldn't receive interface")
        endfunction

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = writeback_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("configuration",this);
            set_config_params();
            uvm_config_db #(writeback_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"env","CONFG",configuration);
            env = writeback_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("env",this);
            main_sequence = writeback_seq #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("main_sequence",this);
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

    endclass:writeback_test




endpackage:writeback_test_pkg