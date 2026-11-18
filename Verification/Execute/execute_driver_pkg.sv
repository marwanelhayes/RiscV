// =============================================================================
// execute_driver_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage driver: applies each execute_item to the DUT through execute_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package execute_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import execute_item_pkg::*;

    // =========================================================================
    // execute_driver: drive Execute stage stimulus through the virtual interface
    // =========================================================================
    class execute_driver extends base_driver #(execute_item, virtual execute_interface);

        `uvm_component_utils(execute_driver)

        function new (string name = "execute_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:execute_driver

endpackage:execute_driver_pkg
