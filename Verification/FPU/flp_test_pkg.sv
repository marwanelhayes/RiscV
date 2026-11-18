// =============================================================================
// flp_test_pkg.sv
// -----------------------------------------------------------------------------
// FPU test: active flp_env driven by flp_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
// =============================================================================
package flp_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import flp_env_pkg::*;
    import flp_seq_pkg::*;
    import flp_config_pkg::*;

    // =========================================================================
    // flp_test: stand-alone FPU test
    // =========================================================================
    class flp_test extends block_test #(flp_config, flp_env, flp_seq, virtual flp_interface);

        `uvm_component_utils(flp_test)

        function new (string name = "flp_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

    endclass:flp_test

endpackage:flp_test_pkg
