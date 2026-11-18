// =============================================================================
// csr_driver_pkg.sv
// -----------------------------------------------------------------------------
// CSR file driver: applies each csr_item to the DUT through csr_interface.
//
// All behaviour is inherited from tb_base_pkg::base_driver.
// =============================================================================
package csr_driver_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import csr_item_pkg::*;

    // =========================================================================
    // csr_driver: drive CSR file stimulus through the virtual interface
    // =========================================================================
    class csr_driver extends base_driver #(csr_item, virtual csr_interface);

        `uvm_component_utils(csr_driver)

        function new (string name = "csr_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:csr_driver

endpackage:csr_driver_pkg
