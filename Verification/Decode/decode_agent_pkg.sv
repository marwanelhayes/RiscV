// =============================================================================
// decode_agent_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package decode_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import decode_driver_pkg::*;
    import decode_monitor_pkg::*;
    import decode_config_pkg::*;
    import decode_item_pkg::*;

    // =========================================================================
    // decode_agent: Decode stage driver, sequencer and monitor
    // =========================================================================
    class decode_agent extends base_agent #(decode_item, decode_driver, decode_monitor, decode_config);

        `uvm_component_utils(decode_agent)

        function new (string name = "decode_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:decode_agent

endpackage:decode_agent_pkg
