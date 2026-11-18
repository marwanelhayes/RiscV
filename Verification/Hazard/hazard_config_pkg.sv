// =============================================================================
// hazard_config_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package hazard_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // hazard_config: agent mode and hazard_interface handle
    // =========================================================================
    class hazard_config extends base_config #(virtual hazard_interface);

        `uvm_object_utils(hazard_config)

        function new (string name = "hazard_config");
            super.new(name);
        endfunction:new

    endclass:hazard_config

endpackage:hazard_config_pkg
