// =============================================================================
// csr_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// CSR file scoreboard: in-order comparison of monitored and predicted items.
// The reference model is csr_predictor; csr_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package csr_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import csr_item_pkg::*;

    // =========================================================================
    // csr_scoreboard: in-order comparator for the CSR file
    // =========================================================================
    class csr_scoreboard extends base_scoreboard #(csr_item);

        `uvm_component_utils(csr_scoreboard)

        function new (string name = "csr_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:csr_scoreboard

endpackage:csr_scoreboard_pkg
