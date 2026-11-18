// =============================================================================
// flp_scoreboard_pkg.sv
// -----------------------------------------------------------------------------
// FPU scoreboard: in-order comparison of monitored and predicted items.
// The reference model is flp_predictor; flp_item::do_compare picks the fields.
//
// All behaviour is inherited from tb_base_pkg::base_scoreboard.
// =============================================================================
package flp_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import tb_base_pkg::*;
    import flp_item_pkg::*;

    // =========================================================================
    // flp_scoreboard: in-order comparator for the FPU
    // =========================================================================
    class flp_scoreboard extends base_scoreboard #(flp_item);

        `uvm_component_utils(flp_scoreboard)

        function new (string name = "flp_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction:new

    endclass:flp_scoreboard

endpackage:flp_scoreboard_pkg
