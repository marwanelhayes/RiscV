// =============================================================================
// hazard_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit scoreboard: in-order comparison of monitored and predicted items.
// The reference model is hazard_predictor; hazard_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package hazard_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import hazard_item_pkg::*;

    // =========================================================================
    // hazard_scoreboard: in-order comparator for the Hazard unit
    // =========================================================================
    class hazard_scoreboard extends base_scoreboard #(hazard_item);

        `uvm_component_utils(hazard_scoreboard)

        function new (string name = "hazard_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:hazard_scoreboard

endpackage:hazard_scoreboard_pkg
