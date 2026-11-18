// =============================================================================
// csr_test_pkg.sv
// -----------------------------------------------------------------------------
// CSR file test: active csr_env driven by csr_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
//
// After the main sequence the reg checker sweeps every CSR (model == DUT).
// =============================================================================
package csr_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import csr_env_pkg::*;
    import csr_seq_pkg::*;
    import csr_config_pkg::*;

    // =========================================================================
    // csr_test: stand-alone CSR file test
    // =========================================================================
    class csr_test extends block_test #(csr_config, csr_env, csr_seq, virtual csr_interface);

        `uvm_component_utils(csr_test)

        function new (string name = "csr_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        virtual task post_main ();
            env.reg_checker.do_final_sweep();
        endtask:post_main

    endclass:csr_test

endpackage:csr_test_pkg
