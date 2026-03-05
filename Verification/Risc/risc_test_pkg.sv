package risc_test_pkg;
    
    `include "parameters_risc.svh"
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import fetch_config_pkg::*;
    import fetch_env_pkg::*;

    import mem_config_pkg::*;
    import mem_env_pkg::*;

    import decode_config_pkg::*;
    import decode_env_pkg::*;

    import execute_config_pkg::*;
    import execute_env_pkg::*;

    import writeback_config_pkg::*;
    import writeback_env_pkg::*;

    import hazard_config_pkg::*;
    import hazard_env_pkg::*;

    class risc_test extends uvm_test;

        //Register the class into the factory
        `uvm_component_utils(risc_test)

        //Override the constructor function
        function new (string name = "risc_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        localparam int MEM_DEPTH = 2**(`ADDR_WIDTH-2);
        localparam int WAIT = MEM_DEPTH + 10;

        //Configuration objects for all pipeline stages
        mem_config #(`DATA_WIDTH,`ADDR_WIDTH) MemoryConfiguration;
        fetch_config #(`DATA_WIDTH,`ADDR_WIDTH) FetchConfiguration;
        decode_config #(`DATA_WIDTH,`ADDR_WIDTH) DecodeConfiguration;
        execute_config #(`DATA_WIDTH,`ADDR_WIDTH) ExecuteConfiguration;
        writeback_config #(`DATA_WIDTH,`ADDR_WIDTH) WritebackConfiguration;
        hazard_config #(`DATA_WIDTH,`ADDR_WIDTH) HazardConfiguration;

        //Environments for all pipeline stages
        mem_env #(`DATA_WIDTH,`ADDR_WIDTH) MemoryEnvironment;
        fetch_env #(`DATA_WIDTH,`ADDR_WIDTH) FetchEnvironment;
        decode_env #(`DATA_WIDTH,`ADDR_WIDTH) DecodeEnvironment;
        execute_env #(`DATA_WIDTH,`ADDR_WIDTH) ExecuteEnvironment;
        writeback_env #(`DATA_WIDTH,`ADDR_WIDTH) WritebackEnvironment;
        hazard_env #(`DATA_WIDTH,`ADDR_WIDTH) HazardEnvironment;

        virtual risc_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) intf;

        function void set_config_params();

            MemoryConfiguration.enable = UVM_PASSIVE;
            FetchConfiguration.enable = UVM_PASSIVE;
            DecodeConfiguration.enable = UVM_PASSIVE;
            ExecuteConfiguration.enable = UVM_PASSIVE;
            WritebackConfiguration.enable = UVM_PASSIVE;
            HazardConfiguration.enable = UVM_PASSIVE;
            
            if(!uvm_config_db #(virtual fetch_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",FetchConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive fetch interface")
            
            if(!uvm_config_db #(virtual decode_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",DecodeConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive decode interface")
            
            if(!uvm_config_db #(virtual execute_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",ExecuteConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive execute interface")
            
            if(!uvm_config_db #(virtual writeback_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",WritebackConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive writeback interface")
            
            if(!uvm_config_db #(virtual mem_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",MemoryConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive memory interface")

            if(!uvm_config_db #(virtual risc_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",intf))
                `uvm_fatal("TEST","Couldn't receive risc interface")

            if(!uvm_config_db #(virtual hazard_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)))::get(this,"","INTF",HazardConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive hazard interface")
        
        endfunction

        virtual function void build_phase (uvm_phase phase);
            
            super.build_phase(phase);
            
            FetchConfiguration = fetch_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("FetchConfiguration",this);
            DecodeConfiguration = decode_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("DecodeConfiguration",this);
            MemoryConfiguration = mem_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("MemoryConfiguration",this);
            ExecuteConfiguration = execute_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("ExecuteConfiguration",this);
            WritebackConfiguration = writeback_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("WritebackConfiguration",this);
            HazardConfiguration = hazard_config #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("HazardConfiguration",this);

            set_config_params();
            
            uvm_config_db #(mem_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"MemoryEnvironment","CONFG",MemoryConfiguration);
            uvm_config_db #(fetch_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"FetchEnvironment","CONFG",FetchConfiguration);
            uvm_config_db #(decode_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"DecodeEnvironment","CONFG",DecodeConfiguration);
            uvm_config_db #(execute_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"ExecuteEnvironment","CONFG",ExecuteConfiguration);
            uvm_config_db #(writeback_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"WritebackEnvironment","CONFG",WritebackConfiguration);
            uvm_config_db #(hazard_config #(`DATA_WIDTH,`ADDR_WIDTH))::set(this,"HazardEnvironment","CONFG",HazardConfiguration);

            MemoryEnvironment = mem_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("MemoryEnvironment",this);
            FetchEnvironment = fetch_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("FetchEnvironment",this);
            DecodeEnvironment = decode_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("DecodeEnvironment",this);
            ExecuteEnvironment = execute_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("ExecuteEnvironment",this);
            WritebackEnvironment = writeback_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("WritebackEnvironment",this);
            HazardEnvironment = hazard_env #(`DATA_WIDTH,`ADDR_WIDTH)::type_id::create("HazardEnvironment",this);
                
        endfunction:build_phase

        virtual function void end_of_elaboration_phase (uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction:end_of_elaboration_phase
        
        virtual task run_phase (uvm_phase phase);
            phase.raise_objection(this);
            //Initialize the clocking block
            intf.initialize();
            `uvm_info("TEST",$sformatf("Starting the test with WAIT = %0d",WAIT),UVM_LOW)
                repeat(WAIT)
                begin
                    @(posedge intf.clk);
                end
            phase.drop_objection(this);
        endtask:run_phase

    endclass:risc_test




endpackage:risc_test_pkg