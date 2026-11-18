// =============================================================================
// mem_driver_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage driver: applies each mem_item to the DUT through mem_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package mem_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import mem_item_pkg::*;

    // =========================================================================
    // mem_driver: drive Memory stage stimulus through the virtual interface
    // =========================================================================
    class mem_driver extends base_driver #(mem_item, virtual mem_interface);

        `uvm_component_utils(mem_driver)

        function new (string name = "mem_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:mem_driver

endpackage:mem_driver_pkg
