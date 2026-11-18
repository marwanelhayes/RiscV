// =============================================================================
// fetch_config_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package fetch_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // fetch_config: agent mode and fetch_interface handle
    // =========================================================================
    class fetch_config extends base_config #(virtual fetch_interface);

        `uvm_object_utils(fetch_config)

        function new (string name = "fetch_config");
            super.new(name);
        endfunction:new

    endclass:fetch_config

endpackage:fetch_config_pkg
