// =============================================================================
// hazard_monitor_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit monitor: samples hazard_interface and publishes each hazard_item.
//
// All behaviour is inherited from tb_base_pkg::base_monitor.
// =============================================================================
package hazard_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import hazard_item_pkg::*;

    // =========================================================================
    // hazard_monitor: sample the Hazard unit and publish a copy of each item
    // =========================================================================
    class hazard_monitor extends base_monitor #(hazard_item, virtual hazard_interface);

        `uvm_component_utils(hazard_monitor)

        function new (string name = "hazard_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:hazard_monitor

endpackage:hazard_monitor_pkg
