// =============================================================================
// hazard_test_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit test: active hazard_env driven by hazard_seq.
//
// Configuration, environment, main sequence and objection handling come from
// tb_base_pkg::block_test.
//
// After the random sequence a directed sequence restricts the registers to
// three per file, so forwarding and stall cases are hit often.
// =============================================================================
package hazard_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import hazard_env_pkg::*;
    import hazard_seq_pkg::*;
    import hazard_config_pkg::*;

    // =========================================================================
    // hazard_test: stand-alone Hazard unit test
    // =========================================================================
    class hazard_test extends block_test #(hazard_config, hazard_env, hazard_seq, virtual hazard_interface);

        `uvm_component_utils(hazard_test)

        function new (string name = "hazard_test", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        hazard_directed_seq directed_sequence;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            directed_sequence = hazard_directed_seq::type_id::create("directed_sequence",this);
        endfunction:build_phase

        virtual task post_main ();
            directed_sequence.start(env.agent.seq);
        endtask:post_main

    endclass:hazard_test

endpackage:hazard_test_pkg
