// =============================================================================
// writeback_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage scoreboard: in-order comparison of monitored and predicted items.
// The reference model is writeback_predictor; writeback_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package writeback_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import writeback_item_pkg::*;

    // =========================================================================
    // writeback_scoreboard: in-order comparator for the Write-back stage
    // =========================================================================
    class writeback_scoreboard extends base_scoreboard #(writeback_item);

        `uvm_component_utils(writeback_scoreboard)

        function new (string name = "writeback_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:writeback_scoreboard

endpackage:writeback_scoreboard_pkg
