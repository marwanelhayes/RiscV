// =============================================================================
// execute_seq_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage sequences.
//
// execute_seq: 10000 fully random items.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package execute_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import execute_item_pkg::*;

    // =========================================================================
    // execute_seq: 10000 random Execute stage items
    // =========================================================================
    class execute_seq extends base_seq #(execute_item);

        `uvm_object_utils(execute_seq)

        function new (string name = "execute_seq");
            super.new(name);
            num_items = 10000;
        endfunction:new

    endclass:execute_seq

endpackage:execute_seq_pkg
