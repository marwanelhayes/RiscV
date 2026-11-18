// =============================================================================
// decode_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage scoreboard: in-order comparison of monitored and predicted items.
// The reference model is decode_predictor; decode_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package decode_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import decode_item_pkg::*;

    // =========================================================================
    // decode_scoreboard: in-order comparator for the Decode stage
    // =========================================================================
    class decode_scoreboard extends base_scoreboard #(decode_item);

        `uvm_component_utils(decode_scoreboard)

        function new (string name = "decode_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:decode_scoreboard

endpackage:decode_scoreboard_pkg
