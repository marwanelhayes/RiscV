// =============================================================================
// hazard_driver_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit driver: applies each hazard_item to the DUT through hazard_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package hazard_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import hazard_item_pkg::*;

    // =========================================================================
    // hazard_driver: drive Hazard unit stimulus through the virtual interface
    // =========================================================================
    class hazard_driver extends base_driver #(hazard_item, virtual hazard_interface);

        `uvm_component_utils(hazard_driver)

        function new (string name = "hazard_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:hazard_driver

endpackage:hazard_driver_pkg
