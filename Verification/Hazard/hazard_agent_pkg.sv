// =============================================================================
// hazard_agent_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package hazard_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import hazard_driver_pkg::*;
    import hazard_monitor_pkg::*;
    import hazard_config_pkg::*;
    import hazard_item_pkg::*;

    // =========================================================================
    // hazard_agent: Hazard unit driver, sequencer and monitor
    // =========================================================================
    class hazard_agent extends base_agent #(hazard_item, hazard_driver, hazard_monitor, hazard_config);

        `uvm_component_utils(hazard_agent)

        function new (string name = "hazard_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:hazard_agent

endpackage:hazard_agent_pkg
