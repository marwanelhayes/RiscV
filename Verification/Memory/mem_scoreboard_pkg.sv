// =============================================================================
// mem_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage scoreboard: in-order comparison of monitored and predicted items.
// The reference model is mem_predictor; mem_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package mem_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import mem_item_pkg::*;

    // =========================================================================
    // mem_scoreboard: in-order comparator for the Memory stage
    // =========================================================================
    class mem_scoreboard extends base_scoreboard #(mem_item);

        `uvm_component_utils(mem_scoreboard)

        function new (string name = "mem_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:mem_scoreboard

endpackage:mem_scoreboard_pkg
