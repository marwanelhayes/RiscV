// =============================================================================
// csr_monitor_pkg.sv
// -----------------------------------------------------------------------------
// CSR file monitor: samples csr_interface and publishes each csr_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package csr_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import csr_item_pkg::*;

    // =========================================================================
    // csr_monitor: sample the CSR file and publish a copy of each item
    // =========================================================================
    class csr_monitor extends base_monitor #(csr_item, virtual csr_interface);

        `uvm_component_utils(csr_monitor)

        function new (string name = "csr_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:csr_monitor

endpackage:csr_monitor_pkg
