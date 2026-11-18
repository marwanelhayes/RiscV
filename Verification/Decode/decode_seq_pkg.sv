// =============================================================================
// decode_seq_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage sequences.
//
// decode_seq: 100000 fully random items.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package decode_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import decode_item_pkg::*;

    // =========================================================================
    // decode_seq: 100000 random Decode stage items
    // =========================================================================
    class decode_seq extends base_seq #(decode_item);

        `uvm_object_utils(decode_seq)

        function new (string name = "decode_seq");
            super.new(name);
            num_items = 100000;
        endfunction:new

    endclass:decode_seq

endpackage:decode_seq_pkg
