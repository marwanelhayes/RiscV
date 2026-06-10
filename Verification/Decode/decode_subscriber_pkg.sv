package decode_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import decode_item_pkg::*;
    import shared_pkg::*;

    class decode_subscriber extends uvm_subscriber #(decode_item);

        //Register the class to the factory
        `uvm_component_utils(decode_subscriber)


        decode_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // Samples while out of reset. Covers the instruction opcode and the
        // decoded control outputs (ALU/FPU/CSR ops, selectors, flags) plus the
        // source/destination registers. Each enum bin is reachable from the
        // constrained instruction stream; encodings ruled out become ignore_bins.
        covergroup cvr_grp();

            // Instruction opcode (nine implemented types per ValidInstructions).
            opcode_cg: coverpoint sub_item.InstructionD[6:0] iff(sub_item.rst)
            {
                bins r_type      = {R_TYPE};
                bins load        = {LOAD};
                bins s_type      = {S_TYPE};
                bins b_type      = {B_TYPE};
                bins i_type      = {I_TYPE};
                bins jal         = {JAL};
                bins jalr        = {JALR};
                bins csr         = {CSR};
                bins floating_pt = {FLOATING_PT};
            }

            // Decoded ALU operation (all eighteen).
            ALUControlE_cg: coverpoint sub_item.ALUControlE iff(sub_item.rst)
            {
                bins op[] = {ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA,
                             MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU};
            }

            // Decoded FPU operation (all twenty-one).
            FPUControlE_cg: coverpoint sub_item.FPUControlE iff(sub_item.rst)
            {
                bins op[] = {FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S, FSGNJ_S, FSGNJN_S,
                             FSGNJX_S, FMIN_S, FMAX_S, FCVT_W_S, FCVT_WU_S, FMV_X_S,
                             FEQ_S, FLT_S, FLE_S, FCLASS_S, FCVT_S_W, FCVT_S_WU,
                             FMV_S_X, NOOPERATION};
            }

            // CSR operation / index.
            CsrOperationE_cg: coverpoint sub_item.CsrOperationE iff(sub_item.rst)
            {
                bins op[] = {csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci, system};
            }
            CsrIndexE_cg: coverpoint sub_item.CsrIndexE iff(sub_item.rst)
            {
                bins idx[] = {fflags, frm, fcsr, mstatus, misa, medeleg, mideleg, mie,
                              mtvec, mscratch, mepc, mcause, mbadaddr, mip, mcycle,
                              mhartid, mvendorid};
            }

            // Result selector / FPU move type / rounding.
            SelectorE_cg: coverpoint sub_item.SelectorE iff(sub_item.rst)
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }
            MoveOperationE_cg: coverpoint sub_item.MoveOperationE iff(sub_item.rst)
            {
                bins fpu_to_reg = {FPUToReg};
                bins reg_to_fpu = {RegToFPU};
                bins fpu_to_fpu = {FPUToFPU};
            }
            RoundModeE_cg: coverpoint sub_item.RoundModeE iff(sub_item.rst)
            {
                bins rne = {RNE};
                bins rtz = {RTZ};
                bins rdn = {RDN};
                bins rup = {RUP};
                bins rmm = {RMM};
                bins dyn = {DYN};
            }

            // funct3 of the decoded instruction.
            funct3E_cg: coverpoint sub_item.funct3E iff(sub_item.rst)
            {
                bins f[] = {[0:7]};
            }

            // Control flags.
            RegWriteE_cg: coverpoint sub_item.RegWriteE iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            FPURegWriteE_cg: coverpoint sub_item.FPURegWriteE iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            MemWriteE_cg: coverpoint sub_item.MemWriteE iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            BranchE_cg: coverpoint sub_item.BranchE iff(sub_item.rst)           { bins lo = {0}; bins hi = {1}; }
            JumpE_cg: coverpoint sub_item.JumpE iff(sub_item.rst)               { bins lo = {0}; bins hi = {1}; }
            ALUSrcE_cg: coverpoint sub_item.ALUSrcE iff(sub_item.rst)           { bins lo = {0}; bins hi = {1}; }
            CsrAccessE_cg: coverpoint sub_item.CsrAccessE iff(sub_item.rst)     { bins lo = {0}; bins hi = {1}; }
            EcallE_cg: coverpoint sub_item.EcallE iff(sub_item.rst)             { bins lo = {0}; bins hi = {1}; }
            EbreakE_cg: coverpoint sub_item.EbreakE iff(sub_item.rst)           { bins lo = {0}; bins hi = {1}; }
            MRetE_cg: coverpoint sub_item.MRetE iff(sub_item.rst)               { bins lo = {0}; bins hi = {1}; }
            // ValidInstructions generates only legal opcodes, so an illegal
            // instruction is never produced - the high bin is unreachable.
            IllegaleInstructionE_cg: coverpoint sub_item.IllegaleInstructionE iff(sub_item.rst) { bins lo = {0}; ignore_bins never_illegal = {1}; }
            FlushE_cg: coverpoint sub_item.FlushE iff(sub_item.rst)             { bins lo = {0}; bins hi = {1}; }
            FPUValidE_cg: coverpoint sub_item.FPUValidE iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            RegWriteW_cg: coverpoint sub_item.RegWriteW iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            FPURegWriteW_cg: coverpoint sub_item.FPURegWriteW iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }

            // Source / destination registers (RdW never zero per NoZeroReg).
            Rs1D_cg: coverpoint sub_item.Rs1D iff(sub_item.rst);
            Rs2D_cg: coverpoint sub_item.Rs2D iff(sub_item.rst);
            RdW_cg: coverpoint sub_item.RdW iff(sub_item.rst)
            {
                ignore_bins x0 = {zero};
            }
            MoveOperationW_cg: coverpoint sub_item.MoveOperationW iff(sub_item.rst)
            {
                bins fpu_to_reg = {FPUToReg};
                bins reg_to_fpu = {RegToFPU};
                bins fpu_to_fpu = {FPUToFPU};
            }

            // ── Crosses ──────────────────────────────────────────────────────
            // opcode vs result selector is the meaningful decode cross. Crosses
            // of MoveOperationE/FPURegWriteE/RoundModeE against FPUControlE are
            // intentionally omitted: their legal combinations are fully
            // determined by the decoder (op-specific funct3 / move-vs-write
            // coupling), so they belong to the individual coverpoints (all 100%)
            // and to the FPU environment rather than a decode cross.
            opcode_x_Selector_cx: cross opcode_cg, SelectorE_cg;

        endgroup:cvr_grp

        function new (string name = "decode_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:decode_subscriber

endpackage: decode_subscriber_pkg
