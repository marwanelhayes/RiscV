// =============================================================================
// writeback_monitor_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage monitor: samples writeback_interface and publishes each writeback_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package writeback_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import writeback_item_pkg::*;

    // =========================================================================
    // writeback_monitor: sample the Write-back stage and publish a copy of each item
    // =========================================================================
    class writeback_monitor extends base_monitor #(writeback_item, virtual writeback_interface);

        `uvm_component_utils(writeback_monitor)

        function new (string name = "writeback_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:writeback_monitor

endpackage:writeback_monitor_pkg
