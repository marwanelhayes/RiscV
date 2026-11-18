// =============================================================================
// flp_agent_pkg.sv
// -----------------------------------------------------------------------------
// FPU agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package flp_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import flp_driver_pkg::*;
    import flp_monitor_pkg::*;
    import flp_config_pkg::*;
    import flp_item_pkg::*;

    // =========================================================================
    // flp_agent: FPU driver, sequencer and monitor
    // =========================================================================
    class flp_agent extends base_agent #(flp_item, flp_driver, flp_monitor, flp_config);

        `uvm_component_utils(flp_agent)

        function new (string name = "flp_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:flp_agent

endpackage:flp_agent_pkg
