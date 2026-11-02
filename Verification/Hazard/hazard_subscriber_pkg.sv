package hazard_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import hazard_item_pkg::*;
    import shared_pkg::*;

    class hazard_subscriber extends uvm_subscriber #(hazard_item);

        //Register the class to the factory
        `uvm_component_utils(hazard_subscriber)


        hazard_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // Hazard unit is purely combinational (no reset field), so every
        // transaction is sampled. Covers the forwarding selects (3 integer /
        // 3 floating encodings), the stall/flush outputs and the control inputs
        // that drive them.
        covergroup cvr_grp();

            // Integer forwarding selects: 000 none, 001 WB, 010 MEM. FP->integer
            // results ride ALUOutM, so there is no separate FPU forward source.
            ForwardAE_cg: coverpoint sub_item.ForwardAE
            {
                bins none   = {3'b000};
                bins wb     = {3'b001};
                bins mem    = {3'b010};
            }
            ForwardBE_cg: coverpoint sub_item.ForwardBE
            {
                bins none   = {3'b000};
                bins wb     = {3'b001};
                bins mem    = {3'b010};
            }

            // Floating forwarding selects: 00 none, 01 WB, 10 MEM.
            ForwardFloatingAE_cg: coverpoint sub_item.ForwardFloatingAE
            {
                bins none = {2'b00};
                bins wb   = {2'b01};
                bins mem  = {2'b10};
            }
            ForwardFloatingBE_cg: coverpoint sub_item.ForwardFloatingBE
            {
                bins none = {2'b00};
                bins wb   = {2'b01};
                bins mem  = {2'b10};
            }

            // Stall / flush outputs.
            StallD_cg: coverpoint sub_item.StallD { bins lo = {0}; bins hi = {1}; }
            StallF_cg: coverpoint sub_item.StallF { bins lo = {0}; bins hi = {1}; }
            FlushE_cg: coverpoint sub_item.FlushE { bins lo = {0}; bins hi = {1}; }
            FlushD_cg: coverpoint sub_item.FlushD { bins lo = {0}; bins hi = {1}; }
            StallE_cg: coverpoint sub_item.StallE { bins lo = {0}; bins hi = {1}; }
            StallM_cg: coverpoint sub_item.StallM { bins lo = {0}; bins hi = {1}; }
            StallW_cg: coverpoint sub_item.StallW { bins lo = {0}; bins hi = {1}; }
            FlushM_cg: coverpoint sub_item.FlushM { bins lo = {0}; bins hi = {1}; }

            // Control inputs driving the hazard logic.
            RegWriteM_cg: coverpoint sub_item.RegWriteM       { bins lo = {0}; bins hi = {1}; }
            RegWriteW_cg: coverpoint sub_item.RegWriteW       { bins lo = {0}; bins hi = {1}; }
            FPURegWriteM_cg: coverpoint sub_item.FPURegWriteM { bins lo = {0}; bins hi = {1}; }
            FPURegWriteW_cg: coverpoint sub_item.FPURegWriteW { bins lo = {0}; bins hi = {1}; }
            PCSrcE_cg: coverpoint sub_item.PCSrcE             { bins lo = {0}; bins hi = {1}; }
            TrapIsSet_cg: coverpoint sub_item.TrapIsSet       { bins lo = {0}; bins hi = {1}; }
            FPUValidE_cg: coverpoint sub_item.FPUValidE       { bins lo = {0}; bins hi = {1}; }
            FPUDoneE_cg: coverpoint sub_item.FPUDoneE         { bins lo = {0}; bins hi = {1}; }
            ICacheHit_cg: coverpoint sub_item.ICacheHit       { bins lo = {0}; bins hi = {1}; }
            DCacheHit_cg: coverpoint sub_item.DCacheHit       { bins lo = {0}; bins hi = {1}; }

            SelectorE_cg: coverpoint sub_item.SelectorE
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }
            // ── Crosses ──────────────────────────────────────────────────────
            RegWriteM_x_RegWriteW_cx: cross RegWriteM_cg, RegWriteW_cg;
            // FPU wait vs cache freeze: decides between bubbling M and freezing it.
            FPUWait_x_DCacheHit_cx:   cross FPUValidE_cg, FPUDoneE_cg, DCacheHit_cg;
            ForwardA_x_ForwardB_cx:   cross ForwardAE_cg, ForwardBE_cg;
            // Load-use bubble vs freeze, and trap squash vs FPU bubble into M.
            StallD_x_StallE_cx:       cross StallD_cg, StallE_cg
            {
                // Holding EX always holds the older stages too.
                ignore_bins e_without_d = binsof(StallD_cg.lo) && binsof(StallE_cg.hi);
            }
            FlushM_x_StallM_cx:       cross FlushM_cg, StallM_cg
            {
                // A freeze holds M, so FlushM can only come from a trap, and
                // a trap needs E to advance (no freeze).
                ignore_bins flush_frozen = binsof(FlushM_cg.hi) && binsof(StallM_cg.hi);
            }

        endgroup:cvr_grp

        function new (string name = "hazard_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:hazard_subscriber

endpackage: hazard_subscriber_pkg
