// =============================================================================
// execute_test_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage test: active execute_env driven by execute_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
// =============================================================================
package execute_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import execute_env_pkg::*;
    import execute_seq_pkg::*;
    import execute_config_pkg::*;

    // =========================================================================
    // execute_test: stand-alone Execute stage test
    // =========================================================================
    class execute_test extends block_test #(execute_config, execute_env, execute_seq, virtual execute_interface);

        `uvm_component_utils(execute_test)

        function new (string name = "execute_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

    endclass:execute_test

endpackage:execute_test_pkg
