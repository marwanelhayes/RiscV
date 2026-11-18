// =============================================================================
// writeback_driver_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage driver: applies each writeback_item to the DUT through writeback_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package writeback_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import writeback_item_pkg::*;

    // =========================================================================
    // writeback_driver: drive Write-back stage stimulus through the virtual interface
    // =========================================================================
    class writeback_driver extends base_driver #(writeback_item, virtual writeback_interface);

        `uvm_component_utils(writeback_driver)

        function new (string name = "writeback_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:writeback_driver

endpackage:writeback_driver_pkg
