package execute_subscriber_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import execute_item_pkg::*;
    import shared_pkg::*;

    class execute_subscriber extends uvm_subscriber #(execute_item);

        //Register the class to the factory
        `uvm_component_param_utils(execute_subscriber)


        execute_item sub_item;

        // ── Functional coverage model ────────────────────────────────────────
        // Sampled while out of reset (rst==1 is normal operation). Bins track
        // the randomised control inputs, forwarding selects, CSR/FPU control and
        // the key datapath outputs. Encodings ruled out by the item constraints
        // become ignore_bins so every defined bin is reachable.
        covergroup cvr_grp();

            // ALU operation (all eighteen ops; free when not branching).
            ALUControlE_cg: coverpoint sub_item.ALUControlE iff(sub_item.rst)
            {
                bins op[] = {ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA,
                             MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU};
            }

            // funct3 field (all eight encodings).
            funct3E_cg: coverpoint sub_item.funct3E iff(sub_item.rst)
            {
                bins f[] = {[0:7]};
            }

            // Control / flag inputs.
            BranchE_cg: coverpoint sub_item.BranchE iff(sub_item.rst)        { bins lo = {0}; bins hi = {1}; }
            JumpE_cg: coverpoint sub_item.JumpE iff(sub_item.rst)            { bins lo = {0}; bins hi = {1}; }
            RegWriteE_cg: coverpoint sub_item.RegWriteE iff(sub_item.rst)    { bins lo = {0}; bins hi = {1}; }
            FPURegWriteE_cg: coverpoint sub_item.FPURegWriteE iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            CsrAccessE_cg: coverpoint sub_item.CsrAccessE iff(sub_item.rst)  { bins lo = {0}; bins hi = {1}; }
            ALUSrcE_cg: coverpoint sub_item.ALUSrcE iff(sub_item.rst)        { bins lo = {0}; bins hi = {1}; }
            MemWriteE_cg: coverpoint sub_item.MemWriteE iff(sub_item.rst)    { bins lo = {0}; bins hi = {1}; }
            MRetE_cg: coverpoint sub_item.MRetE iff(sub_item.rst)            { bins lo = {0}; bins hi = {1}; }
            EcallE_cg: coverpoint sub_item.EcallE iff(sub_item.rst)          { bins lo = {0}; bins hi = {1}; }
            EbreakE_cg: coverpoint sub_item.EbreakE iff(sub_item.rst)        { bins lo = {0}; bins hi = {1}; }
            IllegaleInstructionE_cg: coverpoint sub_item.IllegaleInstructionE iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            TimerInterrupt_cg: coverpoint sub_item.TimerInterrupt iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            SoftwareInterrupt_cg: coverpoint sub_item.SoftwareInterrupt iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            ExternalInterrupt_cg: coverpoint sub_item.ExternalInterrupt iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            FPUValidE_cg: coverpoint sub_item.FPUValidE iff(sub_item.rst)    { bins lo = {0}; bins hi = {1}; }

            // Integer forwarding selects (constrained to 0..4).
            ForwardAE_cg: coverpoint sub_item.ForwardAE iff(sub_item.rst)
            {
                bins no_fwd = {0};
                bins fwd1   = {1};
                bins fwd2   = {2};
                bins fwd3   = {3};
                bins fwd4   = {4};
            }
            ForwardBE_cg: coverpoint sub_item.ForwardBE iff(sub_item.rst)
            {
                bins no_fwd = {0};
                bins fwd1   = {1};
                bins fwd2   = {2};
                bins fwd3   = {3};
                bins fwd4   = {4};
            }

            // Floating forwarding selects (constrained != 2'b11).
            ForwardFloatingAE_cg: coverpoint sub_item.ForwardFloatingAE iff(sub_item.rst)
            {
                bins no_fwd = {0};
                bins fwd1   = {1};
                bins fwd2   = {2};
            }
            ForwardFloatingBE_cg: coverpoint sub_item.ForwardFloatingBE iff(sub_item.rst)
            {
                bins no_fwd = {0};
                bins fwd1   = {1};
                bins fwd2   = {2};
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

            // Result selector.
            SelectorE_cg: coverpoint sub_item.SelectorE iff(sub_item.rst)
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }

            // FPU operation / rounding / move type.
            FPUControlE_cg: coverpoint sub_item.FPUControlE iff(sub_item.rst)
            {
                bins op[] = {FADD_S, FSUB_S, FMUL_S, FDIV_S, FSQRT_S, FSGNJ_S, FSGNJN_S,
                             FSGNJX_S, FMIN_S, FMAX_S, FCVT_W_S, FCVT_WU_S, FMV_X_S,
                             FEQ_S, FLT_S, FLE_S, FCLASS_S, FCVT_S_W, FCVT_S_WU,
                             FMV_S_X, NOOPERATION};
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
            MoveOperationE_cg: coverpoint sub_item.MoveOperationE iff(sub_item.rst)
            {
                bins fpu_to_reg = {FPUToReg};
                bins reg_to_fpu = {RegToFPU};
                bins fpu_to_fpu = {FPUToFPU};
            }

            // Source / destination registers (RdE never zero).
            Rs1E_cg: coverpoint sub_item.Rs1E iff(sub_item.rst);
            RdE_cg: coverpoint sub_item.RdE iff(sub_item.rst)
            {
                ignore_bins x0 = {zero};
            }

            // Output controls.
            PCSrcE_cg: coverpoint sub_item.PCSrcE iff(sub_item.rst)       { bins lo = {0}; bins hi = {1}; }
            RegWriteM_cg: coverpoint sub_item.RegWriteM iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            MemWriteM_cg: coverpoint sub_item.MemWriteM iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            TrapIsSet_cg: coverpoint sub_item.TrapIsSet iff(sub_item.rst) { bins lo = {0}; bins hi = {1}; }
            SelectorM_cg: coverpoint sub_item.SelectorM iff(sub_item.rst)
            {
                bins alu = {ALUToReg};
                bins mem = {MemToReg};
                bins pc  = {PCToReg};
                bins csr = {CSRToReg};
            }

            // Datapath operands / results - sign partition (reachable by random).
            RD1E_cg: coverpoint sub_item.RD1E iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            RD2E_cg: coverpoint sub_item.RD2E iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            SignImmE_cg: coverpoint sub_item.SignImmE iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            ALUOutM_cg: coverpoint sub_item.ALUOutM iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }
            WriteDataM_cg: coverpoint sub_item.WriteDataM iff(sub_item.rst)
            {
                bins negative = {[32'sh8000_0000:-1]};
                bins positive = {[0:32'sh7FFF_FFFF]};
            }

            // ── Crosses ──────────────────────────────────────────────────────
            // ALU op against funct3 (independent when not branching).
            ALUControl_x_funct3_cx: cross ALUControlE_cg, funct3E_cg;

            // funct3 (branch condition) against branch enable.
            funct3_x_Branch_cx: cross funct3E_cg, BranchE_cg;

            // Both forwarding selects together.
            ForwardA_x_ForwardB_cx: cross ForwardAE_cg, ForwardBE_cg;

            // Integer vs floating write enables are mutually exclusive
            // (CantEqualize), so only the opposite-polarity pairs are legal.
            RegWrite_x_FPURegWrite_cx: cross RegWriteE_cg, FPURegWriteE_cg
            {
                ignore_bins both_low  = binsof(RegWriteE_cg.lo) && binsof(FPURegWriteE_cg.lo);
                ignore_bins both_high = binsof(RegWriteE_cg.hi) && binsof(FPURegWriteE_cg.hi);
            }

        endgroup:cvr_grp

        function new (string name = "execute_subscriber", uvm_component parent = null);
            super.new(name,parent);
            cvr_grp = new();
        endfunction

        virtual function void write (T t);
            sub_item = t;
            cvr_grp.sample();
        endfunction

    endclass:execute_subscriber

endpackage: execute_subscriber_pkg
