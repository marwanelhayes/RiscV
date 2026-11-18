// =============================================================================
// tb_base_pkg.sv
// -----------------------------------------------------------------------------
// Shared UVM base classes for every verification environment.
//
// Each unit environment (Fetch, Decode, Execute, Memory, WriteBack, Hazard,
// CSR, FPU) has the same structure: an agent (driver + monitor + sequencer)
// feeds a coverage subscriber, a predictor and an in-order scoreboard. The
// common code for that structure lives here once; a unit class extends the
// matching base class and adds only what is specific to the unit.
//
// Responsibilities:
//   - base_config     : agent mode (active/passive) and virtual interface
//   - base_driver     : get item, drive it through vif.drv2intf()
//   - base_monitor    : sample with vif.intf2mon(), publish a clone
//   - base_agent      : build driver/sequencer (active only) and monitor
//   - base_predictor  : subscriber with the expected-item port (exp_port)
//   - base_scoreboard : in-order comparator (actual FIFO vs expected FIFO)
//   - base_env        : agent -> subscriber, predictor, scoreboard wiring
//   - base_seq        : send num_items randomized items
//   - base_test       : common to every test (topology print)
//   - block_test      : one active unit environment driven by one sequence
//
// Interface contract (used by base_driver and base_monitor):
//   - VIF must provide initialize(), drv2intf(ITEM) and intf2mon(ITEM)
//   - ITEM must provide convert2str()
//
// Message IDs: every class reports with get_type_name(), so the ID is the
// name of the reporting class (for example "execute_scoreboard").
//
// Program directory: tops that load a program (fetch_top, risc_top) take a
// PROGRAM_DIR parameter (vsim -gPROGRAM_DIR=<dir>) and publish it with
// set_program_dir(); readers get file paths from program_file().
// =============================================================================
package tb_base_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ─── Program directory ─────────────────────────────────────────────────────
    // Holds binary1.txt (instruction image, $readmemb), program_info.txt (word
    // count) and, for compliance tests, dmem.hex and tohost.txt. The top calls
    // set_program_dir() in a variable initializer; initializers run before any
    // initial block, so modules and classes can read it from time 0.
    string program_dir;

    function automatic bit set_program_dir (string dir);
        program_dir = dir;
        return 1;
    endfunction:set_program_dir

    function automatic string program_file (string name);
        if(program_dir == "")
            `uvm_fatal("PROGRAM_DIR", "Program directory not set: elaborate the top with -gPROGRAM_DIR=<dir>")
        return {program_dir, "/", name};
    endfunction:program_file

    // =========================================================================
    // base_config: agent mode and virtual interface of one unit environment
    // =========================================================================
    class base_config #(type VIF) extends uvm_object;

        `uvm_object_param_utils(base_config #(VIF))

        function new (string name = "base_config");
            super.new(name);
        endfunction:new

        uvm_active_passive_enum enable;
        VIF vif;

    endclass:base_config

    // =========================================================================
    // base_driver: drive each sequence item through the virtual interface
    // =========================================================================
    class base_driver #(type ITEM, type VIF) extends uvm_driver #(ITEM);

        `uvm_component_param_utils(base_driver #(ITEM, VIF))

        function new (string name = "base_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        VIF vif;
        ITEM drv_item;

        virtual task run_phase (uvm_phase phase);
            super.run_phase(phase);
            vif.initialize();
            forever
            begin:drive
                seq_item_port.get_next_item(drv_item);
                vif.drv2intf(drv_item);
                `uvm_info(get_type_name(), drv_item.convert2str(), UVM_DEBUG)
                seq_item_port.item_done();
            end:drive
        endtask:run_phase

    endclass:base_driver

    // =========================================================================
    // base_monitor: sample the interface and publish a copy of each item
    // =========================================================================
    class base_monitor #(type ITEM, type VIF) extends uvm_monitor;

        `uvm_component_param_utils(base_monitor #(ITEM, VIF))

        function new (string name = "base_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        uvm_analysis_port #(ITEM) mon_port;
        ITEM mon_item, cloned_item;
        VIF vif;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_port = new("mon_port", this);
            mon_item = ITEM::type_id::create("mon_item");
        endfunction:build_phase

        // A clone is published so that subscribers never share the sampling object
        virtual task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever
            begin:monitoring
                vif.intf2mon(mon_item);
                if(!$cast(cloned_item, mon_item.clone()))
                    `uvm_fatal(get_type_name(), "Failed to clone the monitor item")
                mon_port.write(cloned_item);
                `uvm_info(get_type_name(), cloned_item.convert2str(), UVM_HIGH)
            end:monitoring
        endtask:run_phase

    endclass:base_monitor

    // =========================================================================
    // base_agent: driver and sequencer when active, monitor always
    // =========================================================================
    class base_agent #(type ITEM, type DRV, type MON, type CFG) extends uvm_agent;

        `uvm_component_param_utils(base_agent #(ITEM, DRV, MON, CFG))

        function new (string name = "base_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        DRV drv;
        MON mon;
        uvm_sequencer #(ITEM) seq;
        CFG configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(CFG)::get(this, "", "CONFG", configuration))
                `uvm_fatal(get_type_name(), "Agent couldn't receive configuration object")
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv = DRV::type_id::create("drv", this);
                seq = uvm_sequencer #(ITEM)::type_id::create("seq", this);
            end
            mon = MON::type_id::create("mon", this);
        endfunction:build_phase

        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            if(configuration.enable == UVM_ACTIVE)
            begin
                drv.vif = configuration.vif;
                drv.seq_item_port.connect(seq.seq_item_export);
            end
            mon.vif = configuration.vif;
        endfunction:connect_phase

    endclass:base_agent

    // =========================================================================
    // base_predictor: reference model; publishes expected items on exp_port
    // =========================================================================
    virtual class base_predictor #(type ITEM) extends uvm_subscriber #(ITEM);

        function new (string name = "base_predictor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        uvm_analysis_port #(ITEM) exp_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port", this);
        endfunction:build_phase

    endclass:base_predictor

    // =========================================================================
    // base_scoreboard: in-order comparison of actual and expected items
    // =========================================================================
    class base_scoreboard #(type ITEM) extends uvm_scoreboard;

        `uvm_component_param_utils(base_scoreboard #(ITEM))

        function new (string name = "base_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        uvm_tlm_analysis_fifo #(ITEM) actual_fifo;
        uvm_tlm_analysis_fifo #(ITEM) expected_fifo;

        int success;
        int fail;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            actual_fifo   = new("actual_fifo",   this);
            expected_fifo = new("expected_fifo", this);
        endfunction:build_phase

        virtual task run_phase (uvm_phase phase);
            ITEM act, exp;
            forever
            begin
                actual_fifo.get(act);
                expected_fifo.get(exp);
                check_one(act, exp);
            end
        endtask:run_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            actual_fifo.flush();
            expected_fifo.flush();
        endtask:reset_phase

        // ITEM::do_compare decides which fields are checked
        virtual function void check_one (ITEM act, ITEM exp);
            if(!act.compare(exp))
            begin
                `uvm_error(get_type_name(), {"Actual and expected items do not match",
                                             "\n  Expected: ", exp.convert2str(),
                                             "\n  Actual:   ", act.convert2str()})
                fail++;
            end
            else
            begin
                success++;
            end
        endfunction:check_one

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info(get_type_name(), $sformatf("Success count = %0d", success), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("Fail count = %0d", fail), UVM_MEDIUM)
        endfunction:report_phase

    endclass:base_scoreboard

    // =========================================================================
    // base_env: one agent feeding a subscriber, a predictor and a scoreboard
    // =========================================================================
    class base_env #(type CFG, type AGENT, type SB, type SUB, type PRED) extends uvm_env;

        `uvm_component_param_utils(base_env #(CFG, AGENT, SB, SUB, PRED))

        function new (string name = "base_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        AGENT agent;
        SB    scoreboard;
        SUB   sub;
        PRED  predictor;
        CFG   configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(CFG)::get(this, "", "CONFG", configuration))
                `uvm_fatal(get_type_name(), "Environment couldn't receive configuration object")
            uvm_config_db #(CFG)::set(this, "agent", "CONFG", configuration);
            agent      = AGENT::type_id::create("agent", this);
            scoreboard = SB   ::type_id::create("scoreboard", this);
            sub        = SUB  ::type_id::create("sub", this);
            predictor  = PRED ::type_id::create("predictor", this);
        endfunction:build_phase

        // Monitor feeds the coverage subscriber, the predictor and the actual
        // side of the scoreboard; the predictor feeds the expected side
        virtual function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.mon_port.connect(sub.analysis_export);
            agent.mon.mon_port.connect(predictor.analysis_export);
            agent.mon.mon_port.connect(scoreboard.actual_fifo.analysis_export);
            predictor.exp_port.connect(scoreboard.expected_fifo.analysis_export);
        endfunction:connect_phase

    endclass:base_env

    // =========================================================================
    // base_seq: send num_items items, each randomized by randomize_item()
    // =========================================================================
    class base_seq #(type ITEM) extends uvm_sequence #(ITEM);

        `uvm_object_param_utils(base_seq #(ITEM))

        function new (string name = "base_seq");
            super.new(name);
        endfunction:new

        int unsigned num_items;
        ITEM item;

        // Override to add inline constraints or post-randomization edits
        virtual function bit randomize_item ();
            return item.randomize();
        endfunction:randomize_item

        virtual task body ();
            item = ITEM::type_id::create("item");
            repeat(num_items)
            begin:main_sequence
                start_item(item);
                if(!randomize_item())
                    `uvm_error(get_type_name(), "Item randomization failed")
                `uvm_info(get_type_name(), item.convert2str(), UVM_DEBUG)
                finish_item(item);
            end:main_sequence
        endtask:body

    endclass:base_seq

    // =========================================================================
    // base_test: common to every test
    // =========================================================================
    class base_test extends uvm_test;

        `uvm_component_utils(base_test)

        function new (string name = "base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        virtual function void end_of_elaboration_phase (uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction:end_of_elaboration_phase

    endclass:base_test

    // =========================================================================
    // block_test: one active unit environment driven by one main sequence
    // =========================================================================
    class block_test #(type CFG, type ENV, type SEQ, type VIF) extends base_test;

        `uvm_component_param_utils(block_test #(CFG, ENV, SEQ, VIF))

        function new (string name = "block_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

        ENV env;
        SEQ main_sequence;
        CFG configuration;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            configuration = CFG::type_id::create("configuration", this);
            configuration.enable = UVM_ACTIVE;
            if(!uvm_config_db #(VIF)::get(this, "", "INTF", configuration.vif))
                `uvm_fatal(get_type_name(), "Couldn't receive interface")
            uvm_config_db #(CFG)::set(this, "env", "CONFG", configuration);
            env = ENV::type_id::create("env", this);
            main_sequence = SEQ::type_id::create("main_sequence", this);
        endfunction:build_phase

        // Hooks around the main sequence (initial checks, extra sequences, final sweeps)
        virtual task pre_main ();
        endtask:pre_main

        virtual task post_main ();
        endtask:post_main

        virtual task run_phase (uvm_phase phase);
            phase.raise_objection(this);
            pre_main();
            main_sequence.start(env.agent.seq);
            post_main();
            phase.drop_objection(this);
        endtask:run_phase

    endclass:block_test

endpackage:tb_base_pkg
