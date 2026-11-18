// =============================================================================
// fetch_test_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage test: active fetch_env driven by fetch_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
//
// Before the main sequence the instruction memory is checked against the
// program image.
// =============================================================================
package fetch_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import fetch_env_pkg::*;
    import fetch_seq_pkg::*;
    import fetch_config_pkg::*;

    // =========================================================================
    // fetch_test: stand-alone Fetch stage test
    // =========================================================================
    class fetch_test extends block_test #(fetch_config, fetch_env, fetch_seq, virtual fetch_interface);

        `uvm_component_utils(fetch_test)

        function new (string name = "fetch_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        virtual task pre_main ();
            env.mem_checker.check_image();
        endtask:pre_main

    endclass:fetch_test

endpackage:fetch_test_pkg
