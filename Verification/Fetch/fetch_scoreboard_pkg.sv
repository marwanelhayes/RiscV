// =============================================================================
// fetch_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage scoreboard: in-order comparison of monitored and predicted items.
// The reference model is fetch_predictor; fetch_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package fetch_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import fetch_item_pkg::*;

    // =========================================================================
    // fetch_scoreboard: in-order comparator for the Fetch stage
    // =========================================================================
    class fetch_scoreboard extends base_scoreboard #(fetch_item);

        `uvm_component_utils(fetch_scoreboard)

        function new (string name = "fetch_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:fetch_scoreboard

endpackage:fetch_scoreboard_pkg
