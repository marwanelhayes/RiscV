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
//     with TW = 1 is an illegal-instruction exception
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
        typedef logic [XL-1:0] x_t;

        // ── B3 coverage (model state at the cycle the item is sampled) ──────
        covergroup priv_cg with function sample(logic [1:0] mode, bit csr, csr_index_t idx, bit exists,
                                                logic [2:0] cen, bit trap, bit intr, int code,
                                                bit wfi, bit tw, int wake);
            mode_cp:    coverpoint mode { bins u = {2'b00}; bins m = {2'b11}; }
            csr_lvl_cp: coverpoint idx[9:8] iff(csr) { bins lvl[] = {[0:3]}; }
            exists_cp:  coverpoint exists iff(csr) { bins no = {0}; bins yes = {1}; }
            // CSR privilege field x mode x exists
            csr_priv_cx: cross mode_cp, csr_lvl_cp, exists_cp iff(csr)
            {
                ignore_bins no_s_h_csrs = binsof(csr_lvl_cp) intersect {1, 2} && binsof(exists_cp.yes);
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
            rd_cp: coverpoint rd { bins u = {2'b00}; bins m = {2'b11}; }
            mpp_cx: cross wr_cp, rd_cp
            {
                ignore_bins not_legal = (binsof(wr_cp) intersect {3} && binsof(rd_cp.u)) ||
                                        (binsof(wr_cp) intersect {[0:2]} && binsof(rd_cp.m));
            }
        endgroup

        function new (string name = "csr_predictor", uvm_component parent = null);
            super.new(name,parent);
            priv_cg = new();
            mpp_cg = new();
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
            void'(reg_block.regs[mstatus].predict(v, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mcounteren].predict(x_t'(m.mcounteren), .kind(UVM_PREDICT_DIRECT)));
            v = '0; v[3] = m.mie_msie; v[7] = m.mie_mtie; v[11] = m.mie_meie;
            void'(reg_block.regs[mie].predict(v, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mtvec].predict(m.mtvec, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mscratch].predict(m.mscratch, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mepc].predict(m.mepc, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mcause].predict(m.mcause, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[mtval].predict(m.mtval, .kind(UVM_PREDICT_DIRECT)));
            void'(reg_block.regs[minstret].predict(m.minstret[XL-1:0], .kind(UVM_PREDICT_DIRECT)));
        endfunction:mirror

        virtual function void write (csr_item t);
            csr_item exp;
            x_t rv, src, wv, base;
            bit exists, legal, illegal, irq, exc, trap_taken, mret_taken, wr, minstret_written, wake;
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
            m.irq_ext = t.ExternalInterrupt; m.irq_tmr = t.TimerInterrupt; m.irq_sw = t.SoftwareInterrupt;
            m.dut_csr_rdata = '0;
            m.mtime = t.MTime;
            priv = m.priv;
            legal = m.csr_read(t.CsrIndex, rv);             // exists and accessible in this mode
            m.priv = 2'b11;
            exists = m.csr_read(t.CsrIndex, rv);            // read mux value, whatever the mode
            m.priv = priv;
            illegal = (t.CsrAccess && !legal) || m.sys_illegal(t.mret, t.Wfi);
            exc  = (t.Traps != NoTraps) || illegal;
            code = illegal ? 2 : trap_code(t.Traps);
            irq_code = m.irq_code(t.ExternalInterrupt, t.TimerInterrupt, t.SoftwareInterrupt);
            irq  = (irq_code >= 0);
            wake = (m.mie_meie && t.ExternalInterrupt) || (m.mie_msie && t.SoftwareInterrupt) ||
                   (m.mie_mtie && t.TimerInterrupt);       // mip & mie, ignores MIE and mode
            trap_taken = t.Commit && (irq || exc);
            mret_taken = t.Commit && t.mret && !trap_taken;

            exp = csr_item::type_id::create("exp");
            exp.copy_inputs(t);
            exp.CsrOut       = rv;
            exp.chk_csrout   = exists && !(t.CsrIndex inside {mcycle, cycle, mcycleh, cycleh});   // a missing CSR traps, its read value is never used
            exp.TrapTaken    = trap_taken;
            exp.TrapIsSet    = trap_taken || mret_taken;
            exp.RoundingMode = round_mode_t'(m.frm);
            exp.PrivMode     = priv_mode_t'(priv);
            exp.WfiStall     = wfi_wait && !wake;
            base = {m.mtvec[XL-1:2], 2'b00};
            exp.CsrOutPC = trap_taken ? ((irq && (m.mtvec[1:0] == 2'b01)) ? base + x_t'(4 * irq_code) : base) : m.mepc;
            exp_port.write(exp);

            if(t.rst && t.Commit)
                priv_cg.sample(priv, t.CsrAccess, t.CsrIndex, exists, m.mcounteren, trap_taken, irq,
                               irq ? irq_code : code, t.Wfi, m.mstatus_tw,
                               (m.mie_meie && t.ExternalInterrupt) ? 1 : (m.mie_msie && t.SoftwareInterrupt) ? 2 :
                               (m.mie_mtie && t.TimerInterrupt) ? 3 : 0);

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
                else if(t.Commit && t.CsrAccess)
                begin
                    src = (t.CsrOperation inside {csrrwi, csrrsi, csrrci}) ? x_t'(t.Rs) : t.CsrIn;
                    wr  = (t.CsrOperation inside {csrrw, csrrwi}) || (t.Rs != zero);
                    case(t.CsrOperation)
                        csrrw, csrrwi: wv = src;
                        csrrs, csrrsi: wv = rv | src;
                        default:       wv = rv & ~src;
                    endcase
                    // Writes to the read-only space are trapped by decode, so the
                    // CSR file just ignores them (as the model's csr_write does).
                    if(wr && (t.CsrIndex[11:10] != 2'b11)) minstret_written = m.csr_write(t.CsrIndex, wv);
                    if(wr && (t.CsrIndex == mstatus)) mpp_cg.sample(wv[12:11], m.mstatus_mpp);
                end
                if(t.Commit && !trap_taken && !minstret_written)
                    m.minstret = m.minstret + 1;
                if(t.Commit && t.Wfi && !trap_taken) wfi_wait = 1;
                else if(wake)                         wfi_wait = 0;
                mirror();
            end
        endfunction:write

    endclass:csr_predictor

endpackage:csr_predictor_pkg
