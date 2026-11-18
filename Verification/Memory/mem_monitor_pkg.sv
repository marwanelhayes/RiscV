// =============================================================================
// mem_monitor_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage monitor: samples mem_interface and publishes each mem_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package mem_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import mem_item_pkg::*;

    // =========================================================================
    // mem_monitor: sample the Memory stage and publish a copy of each item
    // =========================================================================
    class mem_monitor extends base_monitor #(mem_item, virtual mem_interface);

        `uvm_component_utils(mem_monitor)

        function new (string name = "mem_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:mem_monitor

endpackage:mem_monitor_pkg
