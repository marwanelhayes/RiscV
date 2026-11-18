// =============================================================================
// fetch_monitor_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage monitor: samples fetch_interface and publishes each fetch_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package fetch_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import fetch_item_pkg::*;

    // =========================================================================
    // fetch_monitor: sample the Fetch stage and publish a copy of each item
    // =========================================================================
    class fetch_monitor extends base_monitor #(fetch_item, virtual fetch_interface);

        `uvm_component_utils(fetch_monitor)

        function new (string name = "fetch_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:fetch_monitor

endpackage:fetch_monitor_pkg
