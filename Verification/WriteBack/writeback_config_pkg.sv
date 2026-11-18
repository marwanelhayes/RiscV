// =============================================================================
// writeback_config_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package writeback_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // writeback_config: agent mode and writeback_interface handle
    // =========================================================================
    class writeback_config extends base_config #(virtual writeback_interface);

        `uvm_object_utils(writeback_config)

        function new (string name = "writeback_config");
            super.new(name);
        endfunction:new

    endclass:writeback_config

endpackage:writeback_config_pkg
