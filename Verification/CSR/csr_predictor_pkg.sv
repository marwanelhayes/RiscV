// =============================================================================
// csr_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the CSR file, built on the CSR state of the
// ISA golden model (riscv_iss_pkg), so CSR semantics are defined once, from
// the Privileged spec, for the CSR env, the execute env and the full-core
// checker.
//
// Every CSR output is combinational (the trap is taken in the same cycle):
//   - CsrOut   = read value of CsrIndex (cycle counters are not predicted)
//   - TrapTaken = Commit && (enabled interrupt pending || exception), where an
//     interrupt is taken before the instruction (MEI > MSI > MTI) and an
//     access to an unknown CSR is an illegal-instruction exception
//   - TrapIsSet = TrapTaken || (Commit && mret)
//   - CsrOutPC = trap vector (vectored interrupts: base + 4*cause) or mepc
// State changes when Commit is high and is then mirrored into the RAL.
// =============================================================================
package csr_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import csr_item_pkg::*;
    import csr_reg_block_pkg::*;
    import riscv_iss_pkg::*;

    class csr_predictor extends uvm_subscriber #(csr_item);

        `uvm_component_utils(csr_predictor)

        localparam int XL = FINAL_DATA_WIDTH;
        typedef logic [XL-1:0] x_t;

        function new (string name = "csr_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(csr_item) exp_port;
        csr_reg_block reg_block;
        riscv_iss     m;                // CSR state of the ISA model

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            if(!uvm_config_db #(csr_reg_block)::get(this,"","REG_BLOCK",reg_block))
                `uvm_fatal("CSR_PRED", "predictor could not receive register block")
            m = new();
            mirror();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            m.reset();
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
            void'(reg_block.regs[mstatus].predict(v, .kind(UVM_PREDICT_DIRECT)));
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
            bit exists, irq, exc, trap_taken, mret_taken, wr, minstret_written;
            int code, irq_code;
            iss_commit_t dummy;

            if(!t.rst)
            begin
                m.reset();
                mirror();
            end

            // ── Combinational outputs from the current state ────────────────
            m.irq_ext = t.ExternalInterrupt; m.irq_tmr = t.TimerInterrupt; m.irq_sw = t.SoftwareInterrupt;
            m.dut_csr_rdata = '0;
            exists = m.csr_read(t.CsrIndex, rv);
            exc  = (t.Traps != NoTraps) || (t.CsrAccess && !exists);
            code = (t.CsrAccess && !exists) ? 2 : trap_code(t.Traps);
            irq  = m.mstatus_mie && ((m.mie_meie && t.ExternalInterrupt) ||
                                     (m.mie_msie && t.SoftwareInterrupt) ||
                                     (m.mie_mtie && t.TimerInterrupt));
            irq_code = (m.mie_meie && t.ExternalInterrupt) ? 11 : (m.mie_msie && t.SoftwareInterrupt) ? 3 : 7;
            trap_taken = t.Commit && (irq || exc);
            mret_taken = t.Commit && t.mret && !trap_taken;

            exp = csr_item::type_id::create("exp");
            exp.copy_inputs(t);
            exp.CsrOut       = rv;
            exp.chk_csrout   = !(t.CsrIndex inside {mcycle, cycle, mcycleh, cycleh});
            exp.TrapTaken    = trap_taken;
            exp.TrapIsSet    = trap_taken || mret_taken;
            exp.RoundingMode = round_mode_t'(m.frm);
            base = {m.mtvec[XL-1:2], 2'b00};
            exp.CsrOutPC = trap_taken ? ((irq && (m.mtvec[1:0] == 2'b01)) ? base + x_t'(4 * irq_code) : base) : m.mepc;
            exp_port.write(exp);

            // ── State update on Commit ──────────────────────────────────────
            if(t.rst)
            begin
                minstret_written = 0;
                if(trap_taken)
                begin
                    m.pc = t.PC;
                    m.take_trap(dummy, irq, irq ? irq_code : code,
                                (irq || (t.CsrAccess && !exists)) ? '0 : t.Address);
                end
                else if(mret_taken)
                begin
                    m.mstatus_mie  = m.mstatus_mpie;
                    m.mstatus_mpie = 1;
                end
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
                end
                if(t.Commit && !trap_taken && !minstret_written)
                    m.minstret = m.minstret + 1;
                mirror();
            end
        endfunction:write

    endclass:csr_predictor

endpackage:csr_predictor_pkg
