// =============================================================================
// csr_seq_pkg.sv
// -----------------------------------------------------------------------------
// CSR file sequences.
//
// csr_seq: 10000 fully random items.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package csr_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import csr_item_pkg::*;

    // =========================================================================
    // csr_seq: 10000 random CSR file items
    // =========================================================================
    class csr_seq extends base_seq #(csr_item);

        `uvm_object_utils(csr_seq)

        function new (string name = "csr_seq");
            super.new(name);
            num_items = 10000;
        endfunction:new

    endclass:csr_seq

endpackage:csr_seq_pkg
