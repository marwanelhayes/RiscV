// =============================================================================
// flp_driver_pkg.sv
// -----------------------------------------------------------------------------
// FPU driver: applies each flp_item to the DUT through flp_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package flp_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import flp_item_pkg::*;

    // =========================================================================
    // flp_driver: drive FPU stimulus through the virtual interface
    // =========================================================================
    class flp_driver extends base_driver #(flp_item, virtual flp_interface);

        `uvm_component_utils(flp_driver)

        function new (string name = "flp_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:flp_driver

endpackage:flp_driver_pkg
