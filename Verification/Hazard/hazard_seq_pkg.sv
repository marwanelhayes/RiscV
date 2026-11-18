// =============================================================================
// hazard_seq_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit sequences.
//
// hazard_seq         : 10000 fully random items.
// hazard_directed_seq: 20000 items with registers limited to three per file.
// The item loop comes from tb_base_pkg::base_seq.
// =============================================================================
package hazard_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import tb_base_pkg::*;
    import hazard_item_pkg::*;

    // =========================================================================
    // hazard_seq: 10000 random Hazard unit items
    // =========================================================================
    class hazard_seq extends base_seq #(hazard_item);

        `uvm_object_utils(hazard_seq)

        function new (string name = "hazard_seq");
            super.new(name);
            num_items = 10000;
        endfunction:new

    endclass:hazard_seq

    // =========================================================================
    // hazard_directed_seq: forwarding-biased register choice
    // =========================================================================
    class hazard_directed_seq extends base_seq #(hazard_item);

        `uvm_object_utils(hazard_directed_seq)

        function new (string name = "hazard_directed_seq");
            super.new(name);
            num_items = 20000;
        endfunction:new

        // All sources/destinations come from a tiny shared set, so RdW/RdM often
        // match Rs1E/Rs2E. Random RegWrite*/FPURegWrite* then drive every
        // ForwardAE x ForwardBE combination (WB/MEM), which the uniform-random
        // sequence hits only rarely.
        virtual function bit randomize_item ();
            return item.randomize() with {
                Rs1E  inside {ra, sp, gp};
                Rs2E  inside {ra, sp, gp};
                RdM   inside {ra, sp, gp};
                RdW   inside {ra, sp, gp};
                Rs1FE inside {f1, f2, f3};
                Rs2FE inside {f1, f2, f3};
                RdFM  inside {f1, f2, f3};
                RdFW  inside {f1, f2, f3};
            };
        endfunction:randomize_item

    endclass:hazard_directed_seq

endpackage:hazard_seq_pkg
