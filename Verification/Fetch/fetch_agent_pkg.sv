// =============================================================================
// fetch_agent_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package fetch_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import fetch_driver_pkg::*;
    import fetch_monitor_pkg::*;
    import fetch_config_pkg::*;
    import fetch_item_pkg::*;

    // =========================================================================
    // fetch_agent: Fetch stage driver, sequencer and monitor
    // =========================================================================
    class fetch_agent extends base_agent #(fetch_item, fetch_driver, fetch_monitor, fetch_config);

        `uvm_component_utils(fetch_agent)

        function new (string name = "fetch_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:fetch_agent

endpackage:fetch_agent_pkg
