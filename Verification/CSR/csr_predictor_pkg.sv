// =============================================================================
// csr_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the CSR file, built on the CSR state of the
// ISA golden model (riscv_iss_pkg), so CSR semantics are defined once, from
// the Privileged spec, for the CSR env, the execute env and the full-core
// checker.
//
// Every CSR output is combinational (the trap is taken in the same cycle):
//   - CsrOut   = read value of CsrIndex as the read mux gives it, whatever the
//     mode (cycle counters and missing CSRs, which trap, are not predicted;
//     time/timeh read MTime)
//   - TrapTaken = Commit && (enabled interrupt pending || exception), where an
//     interrupt is taken before the instruction (MEI > MSI > MTI; always
//     enabled below M) and an unknown CSR, a CSR above the current mode, a
//     U-mode counter read blocked by mcounteren, MRET outside M or WFI in U
//     with TW = 1, or an FP instruction / fcsr access with mstatus.FS = Off is an
//     illegal-instruction exception
//   - TrapIsSet = TrapTaken || (Commit && mret)
//   - CsrOutPC = trap vector (vectored interrupts: base + 4*cause) or mepc
//   - PrivMode = current mode; WfiStall = WFI retired and no enabled
//     interrupt line (mip & mie) yet, regardless of mstatus.MIE and mode
// State changes when Commit is high and is then mirrored into the RAL; the
// privilege rules come from the ISA model's helpers (irq_code, sys_illegal,
// do_mret). WfiWait is the only state that changes without Commit.
// =============================================================================
package csr_predictor_pkg;

    import uvm_pkg::*;
    import tb_base_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import csr_item_pkg::*;
    import csr_reg_block_pkg::*;
    import riscv_iss_pkg::*;

    class csr_predictor extends base_predictor #(csr_item);

        `uvm_component_utils(csr_predictor)

        localparam int XL = FINAL_DATA_WIDTH;
        localparam int S_SRC[3] = '{1, 5, 9};           // SSI, STI, SEI
        typedef logic [XL-1:0] x_t;

        // ── B3 coverage (model state at the cycle the item is sampled) ──────
        covergroup priv_cg with function sample(logic [1:0] mode, bit csr, csr_index_t idx, bit exists,
                                                logic [2:0] cen, bit trap, bit intr, int code,
                                                bit wfi, bit tw, int wake);
            mode_cp:    coverpoint mode { bins u = {2'b00}; bins s = {2'b01}; bins m = {2'b11}; }
            csr_lvl_cp: coverpoint idx[9:8] iff(csr) { bins lvl[] = {[0:3]}; }
            exists_cp:  coverpoint exists iff(csr) { bins no = {0}; bins yes = {1}; }
            // CSR privilege field x mode x exists
            csr_priv_cx: cross mode_cp, csr_lvl_cp, exists_cp iff(csr)
            {
                ignore_bins no_h_csrs = binsof(csr_lvl_cp) intersect {2} && binsof(exists_cp.yes);   // no hypervisor CSRs
            }
            // User counter x its mcounteren bit x mode
            counter_cp: coverpoint idx iff(csr)
            {
                bins cy = {cycle, cycleh};
                bins tm = {time_csr, timeh_csr};
                bins ir = {instret, instreth};
            }
            cen_bit_cp: coverpoint (idx inside {cycle, cycleh} ? cen[0] : idx inside {time_csr, timeh_csr} ? cen[1] : cen[2]) iff(csr);
            counter_cx: cross counter_cp, cen_bit_cp, mode_cp iff(csr);
            // Exception cause / interrupt x mode
            exc_cp:  coverpoint code iff(trap && !intr) { bins c[] = {[0:11]}; }
            irq_cp:  coverpoint code iff(trap && intr) { bins c[] = {3, 7, 11}; }
            exc_cx:  cross mode_cp, exc_cp iff(trap && !intr);
            irq_cx:  cross mode_cp, irq_cp iff(trap && intr);
            // WFI x mode x TW x wake source (0 none, 1 MEI, 2 MSI, 3 MTI)
            tw_cp:   coverpoint tw iff(wfi);
            wake_cp: coverpoint wake iff(wfi) { bins w[] = {[0:3]}; }
            wfi_cx:  cross mode_cp, tw_cp, wake_cp iff(wfi);
        endgroup

        // mstatus.MPP written x MPP read back (WARL: 01/10 -> 00)
        covergroup mpp_cg with function sample(logic [1:0] wr, logic [1:0] rd);
            wr_cp: coverpoint wr { bins w[] = {[0:3]}; }
            rd_cp: coverpoint rd { bins u = {2'b00}; bins s = {2'b01}; bins m = {2'b11}; }
            mpp_cx: cross wr_cp, rd_cp
            {
                ignore_bins not_legal = (binsof(wr_cp) intersect {3} && !binsof(rd_cp.m)) ||
                                        (binsof(wr_cp) intersect {1} && !binsof(rd_cp.s)) ||
                                        (binsof(wr_cp) intersect {0, 2} && !binsof(rd_cp.u));
            }
        endgroup

        // B4 mode x delegation x enable, one sample per S-line (SSI/STI/SEI) that is pending
        // while the CSR instruction commits: mie bit, mideleg bit, the global enable the
        // line is subject to (SIE in S, always in U, never in M when delegated; MIE below M
        // always on, in M MIE, when routed to M) and whether it was the interrupt taken
        covergroup s_irq_cg with function sample(logic [1:0] mode, int src, bit ie, bit dlg, bit gie, bit taken);
            mode_cp:  coverpoint mode { bins u = {2'b00}; bins s = {2'b01}; bins m = {2'b11}; }
            src_cp:   coverpoint src { bins ssi = {1}; bins sti = {5}; bins sei = {9}; }
            ie_cp:    coverpoint ie;
            dlg_cp:   coverpoint dlg;
            gie_cp:   coverpoint gie;
            taken_cp: coverpoint taken;
            irq_cx:   cross mode_cp, src_cp, ie_cp, dlg_cp, gie_cp, taken_cp
            {
                ignore_bins taken_not_ready = binsof(taken_cp) intersect {1} && (binsof(ie_cp) intersect {0} || binsof(gie_cp) intersect {0});
                ignore_bins m_not_deleg_gie = binsof(mode_cp.m) && binsof(dlg_cp) intersect {1} && binsof(gie_cp) intersect {1};   // delegated never enabled in M
                ignore_bins u_gie_low = binsof(mode_cp.u) && binsof(gie_cp) intersect {0};   // enabled below M, always
                ignore_bins s_gie_low = binsof(mode_cp.s) && binsof(dlg_cp) intersect {0} && binsof(gie_cp) intersect {0};   // M-routed is on in S
            }
        endgroup

        // B4 S trap entry (mode x delegated synchronous cause) and SRET (SPP x SPIE x SIE, TSR x mode)
        covergroup s_trap_cg with function sample(logic [1:0] mode, int code);
            mode_cp:  coverpoint mode { bins u = {2'b00}; bins s = {2'b01}; }
            cause_cp: coverpoint code { bins c[] = {0, 2, 3, 4, 6, 8, 9}; }
            trap_cx:  cross mode_cp, cause_cp;
        endgroup
        covergroup sret_cg with function sample(bit spp, bit spie, bit sie, bit tsr, logic [1:0] mode, bit illegal);
            spp_cp:  coverpoint spp;
            spie_cp: coverpoint spie;
            sie_cp:  coverpoint sie;
            sret_cx: cross spp_cp, spie_cp, sie_cp iff(!illegal);
            tsr_cp:  coverpoint tsr;
            mode_cp: coverpoint mode { bins u = {2'b00}; bins s = {2'b01}; bins m = {2'b11}; }
            tsr_cx:  cross tsr_cp, mode_cp;
        endgroup

        // B4 mstatus.FS: state x (FP instruction, fcsr access) x outcome
        covergroup fs_cg with function sample(logic [1:0] fs, bit fp, bit fcsr_acc, bit trap);   // trap = illegal-instruction exception
            fs_cp:   coverpoint fs { bins off = {0}; bins initial_ = {1}; bins clean = {2}; bins dirty = {3}; }
            use_cp:  coverpoint {fcsr_acc, fp} { bins none = {0}; bins fp_op = {1}; bins fcsr = {2}; }
            trap_cp: coverpoint trap;
            fs_cx:   cross fs_cp, use_cp, trap_cp
            {
                ignore_bins off_no_trap  = binsof(fs_cp.off) && !binsof(use_cp.none) && binsof(trap_cp) intersect {0};
                ignore_bins on_trap      = !binsof(fs_cp.off) && !binsof(use_cp.none) && binsof(trap_cp) intersect {1};
            }
        endgroup

        function new (string name = "csr_predictor", uvm_component parent = null);
            super.new(name,parent);
            priv_cg = new();
            mpp_cg = new();
            s_irq_cg = new();
            s_trap_cg = new();
            sret_cg = new();
            fs_cg = new();
        endfunction:new

        csr_reg_block reg_block;
        riscv_iss     m;                // CSR state of the ISA model
        bit           wfi_wait;         // WFI retired, waiting for an interrupt line


        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db #(csr_reg_block)::get(this,"","REG_BLOCK",reg_block))
                `uvm_fatal(get_type_name(), "predictor could not receive register block")
            m = new();
            mirror();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            m.reset();
            wfi_wait = 0;
            mirror();
        endtask:reset_phase

        function automatic int trap_code(traps_t t);
            case(t)
                InstructionAddressMisalignedOrUserSoftwareInterrupt: return 0;
                InstructionAccessFaultOrSupervisorSoftwareInterrupt: return 1;
                IllegalInstructionOrHypervisorSoftwareInterrupt:     return 2;
                BreakpointOrMachineSoftwareInterrupt:                return 3;
                LoadAddressMisalignedOrUserSoftwareInterrupt:        return 4;
                LoadAddressFaultOrSupervisorTimerInterrupt:          return 5;
                StoreAddressMisalignedOrHyperVisorTimerInterrupt:    return 6;
                StoreAddressFaultOrMachineTimerInterrupt:            return 7;
                EcallUOrUserExternalInterrupt:                       return 8;
                EcallSOrSupervisorExternalInterrupt:                 return 9;
                EcallHOrHypervisorExternalInterrupt:                 return 10;
                EcallMOrMachineExternalInterrupt:                    return 11;
                default:                                             return 0;
            endcase
        endfunction:trap_code

        // Copy the model's stored CSR state into the RAL mirror
        function void mirror();
            x_t v;
            void'(reg_block.regs[fflags].predict(x_t'(m.fflags), .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[frm].predict(x_t'(m.frm), .kind(UVM_PREDICT_DIRECT)));
            v = '0; v[3] = m.mstatus_mie; v[7] = m.mstatus_mpie;
            v[12:11] = m.mstatus_mpp; v[17] = m.mstatus_mprv; v[21] = m.mstatus_tw;
            v[1] = m.mstatus_sie; v[5] = m.mstatus_spie; v[8] = m.mstatus_spp; v[22] = m.mstatus_tsr;
            v[14:13] = m.mstatus_fs;
            void'(reg_block.regs[mstatus].predict(v, .kind(UVM_PREDICT_DIRECT)));
            v = '0; v[1] = m.mstatus_sie; v[5] = m.mstatus_spie; v[8] = m.mstatus_spp; v[14:13] = m.mstatus_fs;
            void'(reg_block.regs[sstatus].predict(v, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mcounteren].predict(x_t'(m.mcounteren), .kind(UVM_PREDICT_DIRECT)));
            v = '0; v[3] = m.mie_msie; v[7] = m.mie_mtie; v[11] = m.mie_meie;
            v[1] = m.mie_ssie; v[5] = m.mie_stie; v[9] = m.mie_seie;
            void'(reg_block.regs[mie].predict(v, .kind(UVM_PREDICT_DIRECT)));
            v = '0; v[1] = m.mip_ssip; v[5] = m.mip_stip; v[9] = m.mip_seip_sw;     // software bits only
            void'(reg_block.regs[mip].predict(v, .kind(UVM_PREDICT_DIRECT)));
            v = '0; v[1] = m.mideleg[0]; v[5] = m.mideleg[1]; v[9] = m.mideleg[2];
            void'(reg_block.regs[mideleg].predict(v, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[medeleg].predict(x_t'(m.medeleg), .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[scounteren].predict(x_t'(m.scounteren), .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[stvec].predict(m.stvec, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[sscratch].predict(m.sscratch, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[sepc].predict(m.sepc, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[scause].predict(m.scause, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[stval].predict(m.stval, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mtvec].predict(m.mtvec, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mscratch].predict(m.mscratch, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mepc].predict(m.mepc, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mcause].predict(m.mcause, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mtval].predict(m.mtval, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[minstret].predict(m.minstret[XL-1:0], .kind(UVM_PREDICT_DIRECT)));
        endfunction:mirror

        virtual function void write (csr_item t);
            csr_item exp;
            x_t rv, src, wv, base, rmw, tvec;
            bit exists, legal, illegal, irq, exc, trap_taken, mret_taken, sret_taken, to_s, wr, minstret_written, wake;
            int code, irq_code;
            logic [1:0] priv;
            iss_commit_t dummy;

            if(!t.rst)
            begin
                m.reset();
                wfi_wait = 0;
                mirror();
            end

            // ── Combinational outputs from the current state ────────────────
            m.irq_ext = t.ExternalInterrupt; m.irq_tmr = t.TimerInterrupt; m.irq_sw = t.SoftwareInterrupt; m.irq_sext = t.SExternalInterrupt;
            m.dut_csr_rdata = '0;
            m.mtime = t.MTime;
            priv = m.priv;
            legal = m.csr_read(t.CsrIndex, rv);             // exists and accessible in this mode
            m.priv = 2'b11;
            exists = m.csr_read(t.CsrIndex, rv);            // read mux value, whatever the mode
            m.priv = priv;
            illegal = (t.CsrAccess && !legal) || m.sys_illegal(t.mret, t.sret, t.Wfi) ||
                      (t.FpOp && m.mstatus_fs == 2'b00);
            exc  = (t.Traps != NoTraps) || illegal;
            code = illegal ? 2 : trap_code(t.Traps);
            irq_code = m.irq_code(t.ExternalInterrupt, t.TimerInterrupt, t.SoftwareInterrupt, t.SExternalInterrupt);
            irq  = (irq_code >= 0);
            wake = |(m.mip_value() & m.mie_value());       // mip & mie, ignores MIE and mode
            trap_taken = t.Commit && (irq || exc);
            mret_taken = t.Commit && t.mret && !trap_taken;
            sret_taken = t.Commit && t.sret && !trap_taken;
            to_s = m.trap_to_s(irq, irq ? irq_code : code);

            exp = csr_item::type_id::create("exp");
            exp.copy_inputs(t);
            exp.CsrOut       = rv;
            exp.chk_csrout   = exists && !(t.CsrIndex inside {mcycle, cycle, mcycleh, cycleh});   // a missing CSR traps, its read value is never used
            exp.TrapTaken    = trap_taken;
            exp.TrapIsSet    = trap_taken || mret_taken || sret_taken;
            exp.RoundingMode = round_mode_t'(m.frm);
            exp.PrivMode     = priv_mode_t'(priv);
            exp.WfiStall     = wfi_wait && !wake;
            tvec = to_s ? m.stvec : m.mtvec;
            base = {tvec[XL-1:2], 2'b00};
            exp.CsrOutPC = trap_taken ? ((irq && (tvec[1:0] == 2'b01)) ? base + x_t'(4 * irq_code) : base) :
                           sret_taken ? m.sepc : m.mepc;
            exp_port.write(exp);

            if(t.rst && t.Commit)
                priv_cg.sample(priv, t.CsrAccess, t.CsrIndex, exists, m.mcounteren, trap_taken, irq,
                               irq ? irq_code : code, t.Wfi, m.mstatus_tw,
                               (m.mie_meie && t.ExternalInterrupt) ? 1 : (m.mie_msie && t.SoftwareInterrupt) ? 2 :
                               (m.mie_mtie && t.TimerInterrupt) ? 3 : 0);

            // B4 coverage: every pending S line, the S trap entry, SRET and FS
            if(t.rst && t.Commit)
            begin
                x_t pend = m.mip_value();
                x_t ie   = m.mie_value();
                x_t dm   = m.deleg_mask();
                bit en_m = m.mstatus_mie || (priv != 2'b11);
                bit en_s = (priv == 2'b00) || ((priv == 2'b01) && m.mstatus_sie);
                foreach(S_SRC[i])
                    if(pend[S_SRC[i]])
                        s_irq_cg.sample(priv, S_SRC[i], ie[S_SRC[i]], dm[S_SRC[i]], dm[S_SRC[i]] ? en_s : en_m,
                                        trap_taken && irq && irq_code == S_SRC[i]);
                if(trap_taken && to_s && !irq)
                    s_trap_cg.sample(priv, code);
                if(t.sret)
                    sret_cg.sample(m.mstatus_spp, m.mstatus_spie, m.mstatus_sie, m.mstatus_tsr, priv, illegal);
                fs_cg.sample(m.mstatus_fs, t.FpOp, t.CsrAccess && (t.CsrIndex inside {fflags, frm, fcsr}), illegal);
            end

            // ── State update on Commit ──────────────────────────────────────
            if(t.rst)
            begin
                minstret_written = 0;
                if(trap_taken)
                begin
                    m.pc = t.PC;
                    m.take_trap(dummy, irq, irq ? irq_code : code, (irq || illegal) ? '0 : t.Address);
                end
                else if(mret_taken)
                    m.do_mret();
                else if(sret_taken)
                    m.do_sret();
                else if(t.Commit && t.CsrAccess)
                begin
                    src = (t.CsrOperation inside {csrrwi, csrrsi, csrrci}) ? x_t'(t.Rs) : t.CsrIn;
                    wr  = (t.CsrOperation inside {csrrw, csrrwi}) || (t.Rs != zero);
                    rmw = rv;
                    if(t.CsrIndex == mip) rmw[9] = m.mip_seip_sw;   // RMW base: software SEIP, not the line
                    case(t.CsrOperation)
                        csrrw, csrrwi: wv = src;
                        csrrs, csrrsi: wv = rmw | src;
                        default:       wv = rmw & ~src;
                    endcase
                    // Writes to the read-only space are trapped by decode, so the
                    // CSR file just ignores them (as the model's csr_write does).
                    if(wr && (t.CsrIndex[11:10] != 2'b11)) minstret_written = m.csr_write(t.CsrIndex, wv);
                    if(wr && (t.CsrIndex == mstatus)) mpp_cg.sample(wv[12:11], m.mstatus_mpp);
                end
                if(t.Commit && !trap_taken && t.FpOp && t.FpRegWrite)
                    m.mstatus_fs = 2'b11;                           // an FPR write dirties FS
                if(t.Commit && !trap_taken && !minstret_written)
                    m.minstret = m.minstret + 1;
                if(t.Commit && t.Wfi && !trap_taken) wfi_wait = 1;
                else if(wake)                         wfi_wait = 0;
                mirror();
            end
        endfunction:write

    endclass:csr_predictor

endpackage:csr_predictor_pkg
