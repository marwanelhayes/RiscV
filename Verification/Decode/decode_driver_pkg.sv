// =============================================================================
// decode_driver_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage driver: applies each decode_item to the DUT through decode_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package decode_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import decode_item_pkg::*;

    // =========================================================================
    // decode_driver: drive Decode stage stimulus through the virtual interface
    // =========================================================================
    class decode_driver extends base_driver #(decode_item, virtual decode_interface);

        `uvm_component_utils(decode_driver)

        function new (string name = "decode_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:decode_driver

endpackage:decode_driver_pkg
