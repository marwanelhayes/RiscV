// =============================================================================
// decode_config_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage environment configuration: agent mode and virtual interface.
//
// All behaviour is inherited from tb_base_pkg::base_config.
// =============================================================================
package decode_config_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;

    // =========================================================================
    // decode_config: agent mode and decode_interface handle
    // =========================================================================
    class decode_config extends base_config #(virtual decode_interface);

        `uvm_object_utils(decode_config)

        function new (string name = "decode_config");
            super.new(name);
        endfunction:new

    endclass:decode_config

endpackage:decode_config_pkg
