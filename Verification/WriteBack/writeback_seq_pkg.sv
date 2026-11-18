// =============================================================================
// writeback_seq_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage sequences.
//
// writeback_seq: 10000 fully random items.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package writeback_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import writeback_item_pkg::*;

    // =========================================================================
    // writeback_seq: 10000 random Write-back stage items
    // =========================================================================
    class writeback_seq extends base_seq #(writeback_item);

        `uvm_object_utils(writeback_seq)

        function new (string name = "writeback_seq");
            super.new(name);
            num_items = 10000;
        endfunction:new

    endclass:writeback_seq

endpackage:writeback_seq_pkg
