// =============================================================================
// execute_agent_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package execute_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import execute_driver_pkg::*;
    import execute_monitor_pkg::*;
    import execute_config_pkg::*;
    import execute_item_pkg::*;

    // =========================================================================
    // execute_agent: Execute stage driver, sequencer and monitor
    // =========================================================================
    class execute_agent extends base_agent #(execute_item, execute_driver, execute_monitor, execute_config);

        `uvm_component_utils(execute_agent)

        function new (string name = "execute_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:execute_agent

endpackage:execute_agent_pkg
