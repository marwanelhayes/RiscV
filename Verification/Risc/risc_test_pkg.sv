package risc_test_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

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

        localparam int MEM_DEPTH = 2**(FINAL_ADDR_WIDTH-5);
        localparam string PROGRAM_INFO_PATH = "C:/Ain_shams/RiscV/Python/program_info.txt";
        localparam int PROGRAM_EXIT_DRAIN_CYCLES = 4;
        localparam int PROGRAM_SAFETY_MARGIN_CYCLES = 64;
        localparam int PROGRAM_MAX_CYCLE_FACTOR = 8;

        //Configuration objects for all pipeline stages
        mem_config MemoryConfiguration;
        fetch_config FetchConfiguration;
        decode_config DecodeConfiguration;
        execute_config ExecuteConfiguration;
        writeback_config WritebackConfiguration;
        hazard_config HazardConfiguration;

        //Environments for all pipeline stages
        mem_env MemoryEnvironment;
        fetch_env FetchEnvironment;
        decode_env DecodeEnvironment;
        execute_env ExecuteEnvironment;
        writeback_env WritebackEnvironment;
        hazard_env HazardEnvironment;

        virtual risc_interface intf;
        int program_words;
        int wait_cycles;

        function void load_program_metadata();
            int file_descriptor;
            int scan_status;

            program_words = MEM_DEPTH;
            wait_cycles = (MEM_DEPTH * PROGRAM_MAX_CYCLE_FACTOR) + PROGRAM_SAFETY_MARGIN_CYCLES;

            file_descriptor = $fopen(PROGRAM_INFO_PATH, "r");
            if (file_descriptor == 0)
            begin
                `uvm_warning("TEST", $sformatf("Could not open %s, using full memory depth", PROGRAM_INFO_PATH))
                return;
            end

            scan_status = $fscanf(file_descriptor, "%d", program_words);
            $fclose(file_descriptor);

            if (scan_status != 1 || program_words <= 0)
            begin
                program_words = MEM_DEPTH;
                wait_cycles = (MEM_DEPTH * PROGRAM_MAX_CYCLE_FACTOR) + PROGRAM_SAFETY_MARGIN_CYCLES;
                `uvm_warning("TEST", "Program metadata is invalid, using full memory depth")
                return;
            end

            if (program_words > MEM_DEPTH)
            begin
                program_words = MEM_DEPTH;
            end

            wait_cycles = (program_words * PROGRAM_MAX_CYCLE_FACTOR) + PROGRAM_SAFETY_MARGIN_CYCLES;
        endfunction

        function void set_config_params();

            MemoryConfiguration.enable = UVM_PASSIVE;
            FetchConfiguration.enable = UVM_PASSIVE;
            DecodeConfiguration.enable = UVM_PASSIVE;
            ExecuteConfiguration.enable = UVM_PASSIVE;
            WritebackConfiguration.enable = UVM_PASSIVE;
            HazardConfiguration.enable = UVM_PASSIVE;
            
            if(!uvm_config_db #(virtual fetch_interface)::get(this,"","INTF",FetchConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive fetch interface")
            
            if(!uvm_config_db #(virtual decode_interface)::get(this,"","INTF",DecodeConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive decode interface")
            
            if(!uvm_config_db #(virtual execute_interface)::get(this,"","INTF",ExecuteConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive execute interface")
            
            if(!uvm_config_db #(virtual writeback_interface)::get(this,"","INTF",WritebackConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive writeback interface")
            
            if(!uvm_config_db #(virtual mem_interface)::get(this,"","INTF",MemoryConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive memory interface")

            if(!uvm_config_db #(virtual risc_interface)::get(this,"","INTF",intf))
                `uvm_fatal("TEST","Couldn't receive risc interface")

            if(!uvm_config_db #(virtual hazard_interface)::get(this,"","INTF",HazardConfiguration.vif))
                `uvm_fatal("TEST","Couldn't receive hazard interface")
        
        endfunction

        virtual function void build_phase (uvm_phase phase);
            
            super.build_phase(phase);
            
            FetchConfiguration = fetch_config::type_id::create("FetchConfiguration",this);
            DecodeConfiguration = decode_config::type_id::create("DecodeConfiguration",this);
            MemoryConfiguration = mem_config::type_id::create("MemoryConfiguration",this);
            ExecuteConfiguration = execute_config::type_id::create("ExecuteConfiguration",this);
            WritebackConfiguration = writeback_config::type_id::create("WritebackConfiguration",this);
            HazardConfiguration = hazard_config::type_id::create("HazardConfiguration",this);

            set_config_params();
            load_program_metadata();
            
            uvm_config_db #(mem_config)::set(this,"MemoryEnvironment","CONFG",MemoryConfiguration);
            uvm_config_db #(fetch_config)::set(this,"FetchEnvironment","CONFG",FetchConfiguration);
            uvm_config_db #(decode_config)::set(this,"DecodeEnvironment","CONFG",DecodeConfiguration);
            uvm_config_db #(execute_config)::set(this,"ExecuteEnvironment","CONFG",ExecuteConfiguration);
            uvm_config_db #(writeback_config)::set(this,"WritebackEnvironment","CONFG",WritebackConfiguration);
            uvm_config_db #(hazard_config)::set(this,"HazardEnvironment","CONFG",HazardConfiguration);

            MemoryEnvironment = mem_env::type_id::create("MemoryEnvironment",this);
            FetchEnvironment = fetch_env::type_id::create("FetchEnvironment",this);
            DecodeEnvironment = decode_env::type_id::create("DecodeEnvironment",this);
            ExecuteEnvironment = execute_env::type_id::create("ExecuteEnvironment",this);
            WritebackEnvironment = writeback_env::type_id::create("WritebackEnvironment",this);
            HazardEnvironment = hazard_env::type_id::create("HazardEnvironment",this);
                
        endfunction:build_phase

        virtual function void end_of_elaboration_phase (uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction:end_of_elaboration_phase
        
        virtual task run_phase (uvm_phase phase);
            int program_end_pc;
            int cycles_after_program;
            int elapsed_cycles;

            phase.raise_objection(this);
            //Initialize the clocking block
            intf.initialize();
            program_end_pc = program_words * 4;
            cycles_after_program = 0;
            elapsed_cycles = 0;
            `uvm_info(
                "TEST",
                $sformatf(
                    "Starting the test with program_words = %0d, program_end_pc = %0d and safety_wait_cycles = %0d",
                    program_words,
                    program_end_pc,
                    wait_cycles
                ),
                UVM_LOW
            )

            forever
            begin
                @(posedge intf.clk);
                elapsed_cycles++;

                if (FetchConfiguration.vif.PCF >= program_end_pc)
                    cycles_after_program++;
                else
                    cycles_after_program = 0;

                if (cycles_after_program >= PROGRAM_EXIT_DRAIN_CYCLES)
                begin
                    `uvm_info(
                        "TEST",
                        $sformatf(
                            "Stopping after PCF left the program image for %0d consecutive cycles at PCF = %0d after %0d cycles",
                            cycles_after_program,
                            FetchConfiguration.vif.PCF,
                            elapsed_cycles
                        ),
                        UVM_LOW
                    )
                    break;
                end

                if (elapsed_cycles >= wait_cycles)
                begin
                    `uvm_warning(
                        "TEST",
                        $sformatf(
                            "Reached the safety cycle limit (%0d) before PCF exited the program image; stopping at PCF = %0d",
                            wait_cycles,
                            FetchConfiguration.vif.PCF
                        )
                    )
                    break;
                end
            end
            phase.drop_objection(this);
        endtask:run_phase

    endclass:risc_test




endpackage:risc_test_pkg
