// =============================================================================
// flp_config_pkg.sv
// -----------------------------------------------------------------------------
// FPU environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package flp_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // flp_config: agent mode and flp_interface handle
    // =========================================================================
    class flp_config extends base_config #(virtual flp_interface);

        `uvm_object_utils(flp_config)

        function new (string name = "flp_config");
            super.new(name);
        endfunction:new

    endclass:flp_config

endpackage:flp_config_pkg
