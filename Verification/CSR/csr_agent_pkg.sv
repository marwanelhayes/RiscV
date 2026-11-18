// =============================================================================
// csr_agent_pkg.sv
// -----------------------------------------------------------------------------
// CSR file agent: driver and sequencer when active, monitor always.
//
// All behaviour is inherited from tb_base_pkg::base_agent.
// =============================================================================
package csr_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import csr_driver_pkg::*;
    import csr_monitor_pkg::*;
    import csr_config_pkg::*;
    import csr_item_pkg::*;

    // =========================================================================
    // csr_agent: CSR file driver, sequencer and monitor
    // =========================================================================
    class csr_agent extends base_agent #(csr_item, csr_driver, csr_monitor, csr_config);

        `uvm_component_utils(csr_agent)

        function new (string name = "csr_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:csr_agent

endpackage:csr_agent_pkg
