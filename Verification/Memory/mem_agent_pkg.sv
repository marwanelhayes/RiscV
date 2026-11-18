// =============================================================================
// mem_agent_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package mem_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import mem_driver_pkg::*;
    import mem_monitor_pkg::*;
    import mem_config_pkg::*;
    import mem_item_pkg::*;

    // =========================================================================
    // mem_agent: Memory stage driver, sequencer and monitor
    // =========================================================================
    class mem_agent extends base_agent #(mem_item, mem_driver, mem_monitor, mem_config);

        `uvm_component_utils(mem_agent)

        function new (string name = "mem_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:mem_agent

endpackage:mem_agent_pkg
