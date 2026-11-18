// =============================================================================
// execute_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage scoreboard: in-order comparison of monitored and predicted items.
// The reference model is execute_predictor; execute_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package execute_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import execute_item_pkg::*;

    // =========================================================================
    // execute_scoreboard: in-order comparator for the Execute stage
    // =========================================================================
    class execute_scoreboard extends base_scoreboard #(execute_item);

        `uvm_component_utils(execute_scoreboard)

        function new (string name = "execute_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:execute_scoreboard

endpackage:execute_scoreboard_pkg
