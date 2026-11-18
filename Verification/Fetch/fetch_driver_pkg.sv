// =============================================================================
// fetch_driver_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage driver: applies each fetch_item to the DUT through fetch_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package fetch_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import fetch_item_pkg::*;

    // =========================================================================
    // fetch_driver: drive Fetch stage stimulus through the virtual interface
    // =========================================================================
    class fetch_driver extends base_driver #(fetch_item, virtual fetch_interface);

        `uvm_component_utils(fetch_driver)

        function new (string name = "fetch_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:fetch_driver

endpackage:fetch_driver_pkg
