// =============================================================================
// mem_test_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage test: active mem_env driven by mem_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
//
// Before the main sequence the data memory is checked against its initial
// image; afterwards a long sequence without resets exercises the caches.
// =============================================================================
package mem_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import mem_env_pkg::*;
    import mem_seq_pkg::*;
    import mem_config_pkg::*;

    // =========================================================================
    // mem_test: stand-alone Memory stage test
    // =========================================================================
    class mem_test extends block_test #(mem_config, mem_env, mem_seq, virtual mem_interface);

        `uvm_component_utils(mem_test)

        function new (string name = "mem_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_seq_no_rst main_sequence_no_rst;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            main_sequence_no_rst = mem_seq_no_rst::type_id::create("main_sequence_no_rst",this);
        endfunction:build_phase

        virtual task pre_main ();
            env.memory_checker.check_initial_image();
        endtask:pre_main

        virtual task post_main ();
            main_sequence_no_rst.start(env.agent.seq);
        endtask:post_main

    endclass:mem_test

    // =========================================================================
    // mem_berr_test: mem_test with failing write-backs. Run with
    // +AXI_BRESP_ERR_PCT=<n> +MEM_FENCEI so evictions and FENCE.I flushes get
    // SLVERR. The cache must complete them (no hang, loads still match memory);
    // the expected SVA_CACHE_BERR reports are demoted and must occur.
    // =========================================================================
    class mem_berr_test extends mem_test;

        `uvm_component_utils(mem_berr_test)

        function new (string name = "mem_berr_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        virtual function void start_of_simulation_phase (uvm_phase phase);
            super.start_of_simulation_phase(phase);
            uvm_root::get().set_report_severity_id_override(UVM_ERROR, "SVA_CACHE_BERR", UVM_INFO);
        endfunction:start_of_simulation_phase

        virtual function void report_phase (uvm_phase phase);
            int n = uvm_report_server::get_server().get_id_count("SVA_CACHE_BERR");
            super.report_phase(phase);
            if(n == 0)
                `uvm_error(get_type_name(), "no write-back error seen: run with +AXI_BRESP_ERR_PCT=<n> +MEM_FENCEI")
            else
                `uvm_info(get_type_name(), $sformatf("%0d failed write-backs completed", n), UVM_LOW)
        endfunction:report_phase

    endclass:mem_berr_test

endpackage:mem_test_pkg
