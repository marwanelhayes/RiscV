// =============================================================================
// mem_seq_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage sequences.
//
// mem_seq       : 10000 fully random items (resets included).
// mem_seq_no_rst: 1000000 items without reset, so cache state builds up.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package mem_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import mem_item_pkg::*;

    // =========================================================================
    // mem_seq: 10000 random Memory stage items
    // =========================================================================
    class mem_seq extends base_seq #(mem_item);

        `uvm_object_utils(mem_seq)

        function new (string name = "mem_seq");
            super.new(name);
            num_items = 10000;
        endfunction:new

    endclass:mem_seq

    // =========================================================================
    // mem_seq_no_rst: long random run with reset held inactive
    // =========================================================================
    class mem_seq_no_rst extends base_seq #(mem_item);

        `uvm_object_utils(mem_seq_no_rst)

        function new (string name = "mem_seq_no_rst");
            super.new(name);
            num_items = 1000000;
        endfunction:new

        virtual function bit randomize_item ();
            return item.randomize() with {item.rst == 1;};
        endfunction:randomize_item

    endclass:mem_seq_no_rst

endpackage:mem_seq_pkg
