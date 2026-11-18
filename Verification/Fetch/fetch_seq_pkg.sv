// =============================================================================
// fetch_seq_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage sequences.
//
// fetch_seq: 10000 fully random items.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package fetch_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import fetch_item_pkg::*;

    // =========================================================================
    // fetch_seq: 10000 random Fetch stage items
    // =========================================================================
    class fetch_seq extends base_seq #(fetch_item);

        `uvm_object_utils(fetch_seq)

        function new (string name = "fetch_seq");
            super.new(name);
            num_items = 10000;
        endfunction:new

    endclass:fetch_seq

endpackage:fetch_seq_pkg
