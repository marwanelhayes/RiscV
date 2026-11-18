// =============================================================================
// decode_monitor_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage monitor: samples decode_interface and publishes each decode_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package decode_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import decode_item_pkg::*;

    // =========================================================================
    // decode_monitor: sample the Decode stage and publish a copy of each item
    // =========================================================================
    class decode_monitor extends base_monitor #(decode_item, virtual decode_interface);

        `uvm_component_utils(decode_monitor)

        function new (string name = "decode_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:decode_monitor

endpackage:decode_monitor_pkg
