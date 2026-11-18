// =============================================================================
// writeback_agent_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package writeback_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import writeback_driver_pkg::*;
    import writeback_monitor_pkg::*;
    import writeback_config_pkg::*;
    import writeback_item_pkg::*;

    // =========================================================================
    // writeback_agent: Write-back stage driver, sequencer and monitor
    // =========================================================================
    class writeback_agent extends base_agent #(writeback_item, writeback_driver, writeback_monitor, writeback_config);

        `uvm_component_utils(writeback_agent)

        function new (string name = "writeback_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:writeback_agent

endpackage:writeback_agent_pkg
