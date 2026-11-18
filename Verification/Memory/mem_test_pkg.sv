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

endpackage:mem_test_pkg
