package mem_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import mem_item_pkg::*;
    import shared_pkg::*;

    class mem_subscriber extends uvm_subscriber #(mem_item);

        //Register the class to the factory
        `uvm_component_utils(mem_subscriber)


        mem_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // Samples while out of reset. Covers the cache-hit response, access
        // controls, selectors, FP status pass-through and the data busses
        // (sign partition). funct3M is constrained to word (OnlyWord).
        covergroup cvr_grp();

            // Access size - constrained to word only.
            funct3M_cg: coverpoint sub_item.funct3M iff(sub_item.rst)
            {
                bins word = {W};
                ignore_bins others = {B, HW, BU, HWU, 3'b011, 3'b110, 3'b111}; // OnlyWord constraint
            }

            // Cache response.
            CacheHitM_cg: coverpoint sub_item.CacheHitM iff(sub_item.rst)
            {
                bins miss = {0};
                bins hit  = {1};
            }

            // Access / write-back controls.
            MemWriteM_cg: coverpoint sub_item.MemWriteM iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            RegWriteM_cg: coverpoint sub_item.RegWriteM iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            FPURegWriteM_cg: coverpoint sub_item.FPURegWriteM iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            RegWriteW_cg: coverpoint sub_item.RegWriteW iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }

            SelectorM_cg: coverpoint sub_item.SelectorM iff(sub_item.rst)
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }
            SelectorW_cg: coverpoint sub_item.SelectorW iff(sub_item.rst)
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }
            MoveOperationM_cg: coverpoint sub_item.MoveOperationM iff(sub_item.rst)
            {
                bins fpu_to_reg = {FPUToReg};
                bins reg_to_fpu = {RegToFPU};
                bins fpu_to_fpu = {FPUToFPU};
            }

            // FP status flags carried through MEM.
            OverflowM_cg: coverpoint sub_item.OverflowM iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }
            UnderflowM_cg: coverpoint sub_item.UnderflowM iff(sub_item.rst)   { bins lo = {0}; bins hi = {1}; }
            NaNM_cg: coverpoint sub_item.NaNM iff(sub_item.rst)               { bins lo = {0}; bins hi = {1}; }
            InfM_cg: coverpoint sub_item.InfM iff(sub_item.rst)               { bins lo = {0}; bins hi = {1}; }
            ZeroM_cg: coverpoint sub_item.ZeroM iff(sub_item.rst)             { bins lo = {0}; bins hi = {1}; }
            InvalidDivM_cg: coverpoint sub_item.InvalidDivM iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }

            // Destination registers (RdM not zero when RegWriteM).
            RdM_cg: coverpoint sub_item.RdM iff(sub_item.rst)
            {
                ignore_bins x0 = {zero};
            }

            // Data busses - sign partition.
            ALUOutM_cg: coverpoint sub_item.ALUOutM iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            ReadDataW_cg: coverpoint sub_item.ReadDataW iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            ALUOutW_cg: coverpoint sub_item.ALUOutW iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }

            // ── Crosses ──────────────────────────────────────────────────────
            MemWrite_x_CacheHit_cx: cross MemWriteM_cg, CacheHitM_cg;
            Selector_x_RegWrite_cx: cross SelectorM_cg, RegWriteM_cg;

        endgroup:cvr_grp

        function new (string name = "mem_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:mem_subscriber

endpackage: mem_subscriber_pkg
