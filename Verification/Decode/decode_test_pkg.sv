// =============================================================================
// decode_test_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage test: active decode_env driven by decode_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
//
// After the main sequence the reg checker sweeps the register files by backdoor
// (model == DUT).
// =============================================================================
package decode_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import decode_env_pkg::*;
    import decode_seq_pkg::*;
    import decode_config_pkg::*;

    // =========================================================================
    // decode_test: stand-alone Decode stage test
    // =========================================================================
    class decode_test extends block_test #(decode_config, decode_env, decode_seq, virtual decode_interface);

        `uvm_component_utils(decode_test)

        function new (string name = "decode_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        virtual task post_main ();
            env.reg_checker.do_final_sweep();
        endtask:post_main

    endclass:decode_test

endpackage:decode_test_pkg
