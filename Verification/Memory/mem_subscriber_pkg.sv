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
        // (sign partition), plus every load/store size on every legal lane.
        covergroup cvr_grp();

            // Access size and byte lane of the serviced (MEM advancing) access.
            // LWU/LD/SD exist only on RV64; misaligned lanes are excluded
            // because EX traps a misaligned access before MEM.
            LoadSize_cg: coverpoint load_store_t'(sub_item.funct3M) iff(sub_item.rst && sub_item.MemReadM && !sub_item.StallW)
            {
                bins lb = {B}; bins lh = {HW}; bins lw = {W}; bins lbu = {BU}; bins lhu = {HWU};
                bins lwu = {WU} with (FINAL_DATA_WIDTH == 64);
                bins ld  = {D}  with (FINAL_DATA_WIDTH == 64);
            }
            StoreSize_cg: coverpoint load_store_t'(sub_item.funct3M) iff(sub_item.rst && sub_item.MemWriteM && !sub_item.StallW)
            {
                bins sb = {B}; bins sh = {HW}; bins sw = {W};
                bins sd = {D} with (FINAL_DATA_WIDTH == 64);
            }
            Lane_cg: coverpoint sub_item.ALUOutM[$clog2(FINAL_DATA_WIDTH/8)-1:0] iff(sub_item.rst && !sub_item.StallW)
            {
                bins lane[] = {[0:(FINAL_DATA_WIDTH/8)-1]};
            }

            ValidM_cg: coverpoint sub_item.ValidM iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }
            MemReadM_cg: coverpoint sub_item.MemReadM iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            StallW_cg: coverpoint sub_item.StallW iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }

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
            MemRead_x_CacheHit_cx:  cross MemReadM_cg, CacheHitM_cg;
            LoadLane_cx:  cross LoadSize_cg, Lane_cg
            {
                ignore_bins half = binsof(LoadSize_cg) intersect {HW, HWU} && binsof(Lane_cg) intersect {1, 3, 5, 7};
                ignore_bins word = binsof(LoadSize_cg) intersect {W, WU}   && binsof(Lane_cg) intersect {[1:3], [5:7]};
                ignore_bins dbl  = binsof(LoadSize_cg) intersect {D}       && binsof(Lane_cg) intersect {[1:7]};
            }
            StoreLane_cx: cross StoreSize_cg, Lane_cg
            {
                ignore_bins half = binsof(StoreSize_cg) intersect {HW} && binsof(Lane_cg) intersect {1, 3, 5, 7};
                ignore_bins word = binsof(StoreSize_cg) intersect {W}  && binsof(Lane_cg) intersect {[1:3], [5:7]};
                ignore_bins dbl  = binsof(StoreSize_cg) intersect {D}  && binsof(Lane_cg) intersect {[1:7]};
            }

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
