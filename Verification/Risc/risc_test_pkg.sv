// =============================================================================
// risc_test_pkg.sv
// -----------------------------------------------------------------------------
// Full-core tests.
//
// risc_test           : random program (Program/riscv_testcase_generator.py) with
//                       random interrupt pulses; every stage environment is
//                       passive and commit_checker lock-steps the ISS (and Spike).
// risc_compliance_test: one riscv-tests program (Verification/Compliance), no
//                       interrupts; ends on the tohost write.
// =============================================================================
package risc_test_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;

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

    class risc_test extends base_test;

        `uvm_component_utils(risc_test)

        function new (string name = "risc_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        localparam int MEM_DEPTH = 2**(FINAL_ADDR_WIDTH-2);          // 32-bit instruction words
        localparam int PROGRAM_EXIT_DRAIN_CYCLES = 64;    // covers a D-cache write-back + refill
        localparam int PROGRAM_SAFETY_MARGIN_CYCLES = 64;
        localparam int PROGRAM_MAX_CYCLE_FACTOR = 16;

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
        bit drive_irq = 1;      // random interrupt pulses during the program

        function void load_program_metadata();
            int file_descriptor;
            int scan_status;

            program_words = MEM_DEPTH;
            wait_cycles = (MEM_DEPTH * PROGRAM_MAX_CYCLE_FACTOR) + PROGRAM_SAFETY_MARGIN_CYCLES;

            file_descriptor = $fopen(program_file("program_info.txt"), "r");
            if (file_descriptor == 0)
            begin
                `uvm_warning(get_type_name(), $sformatf("Could not open %s, using full memory depth", program_file("program_info.txt")))
                return;
            end

            scan_status = $fscanf(file_descriptor, "%d", program_words);
            $fclose(file_descriptor);

            if (scan_status != 1 || program_words <= 0)
            begin
                program_words = MEM_DEPTH;
                wait_cycles = (MEM_DEPTH * PROGRAM_MAX_CYCLE_FACTOR) + PROGRAM_SAFETY_MARGIN_CYCLES;
                `uvm_warning(get_type_name(), "Program metadata is invalid, using full memory depth")
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
                `uvm_fatal(get_type_name(), "Couldn't receive fetch interface")
            
            if(!uvm_config_db #(virtual decode_interface)::get(this,"","INTF",DecodeConfiguration.vif))
                `uvm_fatal(get_type_name(), "Couldn't receive decode interface")
            
            if(!uvm_config_db #(virtual execute_interface)::get(this,"","INTF",ExecuteConfiguration.vif))
                `uvm_fatal(get_type_name(), "Couldn't receive execute interface")
            
            if(!uvm_config_db #(virtual writeback_interface)::get(this,"","INTF",WritebackConfiguration.vif))
                `uvm_fatal(get_type_name(), "Couldn't receive writeback interface")
            
            if(!uvm_config_db #(virtual mem_interface)::get(this,"","INTF",MemoryConfiguration.vif))
                `uvm_fatal(get_type_name(), "Couldn't receive memory interface")

            if(!uvm_config_db #(virtual risc_interface)::get(this,"","INTF",intf))
                `uvm_fatal(get_type_name(), "Couldn't receive risc interface")

            if(!uvm_config_db #(virtual hazard_interface)::get(this,"","INTF",HazardConfiguration.vif))
                `uvm_fatal(get_type_name(), "Couldn't receive hazard interface")
        
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
            uvm_config_db #(string)::set(this,"MemoryEnvironment.predictor","BKDR_PATH","risc_top.DataMem.mem");
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

        // Stage RAL models default to their stand-alone *_top roots; re-root
        // their backdoor paths into the full core.
        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            FetchEnvironment.reg_block.set_hdl_path_root("risc_top.DataMem");
            DecodeEnvironment.reg_block.set_hdl_path_root("risc_top.DUT.Decode");
            MemoryEnvironment.reg_block.set_hdl_path_root("risc_top.DataMem");
        endfunction:connect_phase

        
        // Random short pulses on one interrupt line. A pulse is shorter than
        // the trap handler, so a taken interrupt is not re-taken; one that
        // arrives while MIE is clear is simply not taken (level-sensitive).
        task drive_interrupts();
            forever
            begin
                repeat($urandom_range(8, 40)) @(intf.cb);
                case($urandom_range(0, 3))
                    0: intf.cb.ExternalInterrupt <= 1;
                    1: intf.cb.TimerInterrupt    <= 1;
                    2: intf.cb.SoftwareInterrupt <= 1;
                    3: intf.cb.SExternalInterrupt <= 1;
                endcase
                repeat($urandom_range(1, 8)) @(intf.cb);
                intf.cb.ExternalInterrupt <= 0;
                intf.cb.TimerInterrupt    <= 0;
                intf.cb.SoftwareInterrupt <= 0;
                intf.cb.SExternalInterrupt <= 0;
            end
        endtask:drive_interrupts

        // The program ends at a self-loop. commit_checker triggers ISS_DONE
        // when the ISS commits it; the pipeline is then drained and ISS_FINAL
        // makes the checker verify that every expected write was seen. Not
        // reaching the end within the cycle budget is a failure (V7).
        virtual task run_phase (uvm_phase phase);
            uvm_event done_ev  = uvm_event_pool::get_global("ISS_DONE");
            uvm_event final_ev = uvm_event_pool::get_global("ISS_FINAL");

            phase.raise_objection(this);
            intf.initialize();
            `uvm_info(get_type_name(), $sformatf("Starting the test: program_words = %0d, cycle budget = %0d",
                                        program_words, wait_cycles), UVM_LOW)
            if(drive_irq)
            fork
                drive_interrupts();
            join_none
            fork
                done_ev.wait_trigger();
                begin
                    repeat(wait_cycles) @(posedge intf.clk);
                    `uvm_error(get_type_name(), $sformatf("program end not reached within %0d cycles", wait_cycles))
                end
            join_any
            disable fork;

            disable drive_interrupts;
            intf.cb.ExternalInterrupt <= 0;
            intf.cb.TimerInterrupt    <= 0;
            intf.cb.SoftwareInterrupt <= 0;
            intf.cb.SExternalInterrupt <= 0;
            repeat(PROGRAM_EXIT_DRAIN_CYCLES) @(posedge intf.clk);
            final_ev.trigger();
            @(posedge intf.clk);
            phase.drop_objection(this);
        endtask:run_phase

    endclass:risc_test

    // =========================================================================
    // risc_compliance_test: one riscv-tests program (Verification/Compliance)
    // =========================================================================
    // Same environment and checkers as risc_test; the program ends with a store
    // to tohost (see commit_checker) and runs without interrupt pulses, which a
    // self-checking test would report as an unexpected trap.
    class risc_compliance_test extends risc_test;

        `uvm_component_utils(risc_compliance_test)

        function new (string name = "risc_compliance_test", uvm_component parent = null);
            super.new(name,parent);
            drive_irq = 0;
        endfunction:new

    endclass:risc_compliance_test




endpackage:risc_test_pkg
