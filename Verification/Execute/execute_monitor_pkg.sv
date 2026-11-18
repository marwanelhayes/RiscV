// =============================================================================
// execute_monitor_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage monitor: samples execute_interface and publishes each execute_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package execute_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import execute_item_pkg::*;

    // =========================================================================
    // execute_monitor: sample the Execute stage and publish a copy of each item
    // =========================================================================
    class execute_monitor extends base_monitor #(execute_item, virtual execute_interface);

        `uvm_component_utils(execute_monitor)

        function new (string name = "execute_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:execute_monitor

endpackage:execute_monitor_pkg
