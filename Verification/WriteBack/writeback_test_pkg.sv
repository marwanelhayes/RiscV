// =============================================================================
// writeback_test_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage test: active writeback_env driven by writeback_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
// =============================================================================
package writeback_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import writeback_env_pkg::*;
    import writeback_seq_pkg::*;
    import writeback_config_pkg::*;

    // =========================================================================
    // writeback_test: stand-alone Write-back stage test
    // =========================================================================
    class writeback_test extends block_test #(writeback_config, writeback_env, writeback_seq, virtual writeback_interface);

        `uvm_component_utils(writeback_test)

        function new (string name = "writeback_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

    endclass:writeback_test

endpackage:writeback_test_pkg
