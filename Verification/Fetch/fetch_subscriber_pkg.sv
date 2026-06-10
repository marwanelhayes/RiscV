// =============================================================================
// fetch_subscriber_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage subscriber package for UVM verification.
// =============================================================================
package fetch_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fetch_item_pkg::*;
    import shared_pkg::*;

    class fetch_subscriber extends uvm_subscriber #(fetch_item);

        //Register the class to the factory
        `uvm_component_utils(fetch_subscriber)


        fetch_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // Covers reset, the stall/flush controls and the cache-hit response.
        // PCF is word aligned (ProgramCounter constraint) so only the aligned
        // bin is meaningful.
        covergroup cvr_grp();

            rst_cg: coverpoint sub_item.rst
            {
                bins active = {0};
                bins idle   = {1};
            }

            StallD_cg: coverpoint sub_item.StallD iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }
            FlushD_cg: coverpoint sub_item.FlushD iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }
            StallBit_cg: coverpoint sub_item.StallBit iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            FlushBit_cg: coverpoint sub_item.FlushBit iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            CacheHitF_cg: coverpoint sub_item.CacheHitF iff(sub_item.rst)
            {
                bins miss = {0};
                bins hit  = {1};
            }

            // PC alignment (always word aligned by constraint).
            PCF_align_cg: coverpoint sub_item.PCF[1:0] iff(sub_item.rst)
            {
                bins aligned = {2'b00};
            }

            // ── Crosses ──────────────────────────────────────────────────────
            Stall_x_Flush_cx:    cross StallD_cg, FlushD_cg;
            CacheHit_x_Flush_cx: cross CacheHitF_cg, FlushD_cg;
            StallBit_x_FlushBit_cx: cross StallBit_cg, FlushBit_cg;

        endgroup:cvr_grp

        function new (string name = "fetch_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:fetch_subscriber

endpackage: fetch_subscriber_pkg
