// =============================================================================
// execute_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Execute stage, written from the ISA.
//
// Models, independently of the RTL:
//   - the operand muxes as the forwarding contract defines them (code 0 = the
//     register value, 1 = the WB result, 2 = the MEM result, where the MEM
//     result is the value the MEM instruction will write: ALU result, link
//     value or CSR read)
//   - every ALU operation, the RV64 word operations and the M extension from
//     the ISA definitions (incl. divide by zero and overflow)
//   - branch conditions, JAL/branch targets and the JALR target (rs1+imm)&~1
//   - the synchronous exceptions of the EX instruction and their mtval
//   - the CSR file and trap/MRET behaviour, using the ISA golden model's CSR
//     state (riscv_iss_pkg), so CSR semantics are defined in one place
//   - FP results with the exact FP reference (flp_ref_pkg)
//
// DUT decoupling (emit-before-update):
//   - PCSrcE, PCTargetE, TrapIsSet, CsrOutPC are combinational: computed from
//     the current item.
//   - The EX/MEM outputs are registered: the shadow emitted now was computed
//     on the previous call. FlushM loads a bubble, StallM holds the register.
//   - CSR state changes when EX commits (ValidE && !StallE), after the
//     combinational outputs of the cycle are computed.
// =============================================================================
package execute_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import execute_item_pkg::*;
    import riscv_iss_pkg::*;
    import flp_ref_pkg::*;

    class execute_predictor extends uvm_subscriber #(execute_item);

        `uvm_component_utils(execute_predictor)

        localparam int XL = FINAL_DATA_WIDTH;
        localparam int LOG_XL = $clog2(FINAL_DATA_WIDTH);
        typedef logic [XL-1:0] x_t;

        function new (string name = "execute_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(execute_item) exp_port;
        execute_item q;                 // EX/MEM shadow
        execute_item shadow_inputs;
        riscv_iss    csr;               // CSR state of the ISA model
        logic [31:0] fres_issued;       // FP result of the instruction in EX (issue-cycle operands)
        bit          stall_e_prev;      // EX was held last cycle: same instruction still in EX

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            q   = execute_item::type_id::create("q");
            csr = new();
            bubble(q);
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            bubble(q);
            csr.reset();
            fres_issued = '0; stall_e_prev = 0;
        endtask:reset_phase

        function void bubble(execute_item e);
            e.ValidM = 0; e.RegWriteM = 0; e.SelectorM = ALUToReg; e.MemWriteM = 0; e.MemReadM = 0;
            e.ALUOutM = '0; e.WriteDataM = '0; e.RdM = zero; e.funct3M = '0; e.PCPlus4M = '0;
            e.CsrOutM = '0; e.RdFM = f0; e.FPUOutM = '0; e.FPURegWriteM = 0; e.MoveOperationM = FPUToFPU;
            e.chk_csrout = 1;
        endfunction:bubble

        function automatic x_t sext32(logic [31:0] v);
            return x_t'(signed'(v));
        endfunction:sext32

        // ── ALU (ISA definitions) ───────────────────────────────────────────
        function automatic x_t alu(alu_operation_t op, x_t a, x_t b, bit word);
            logic [2:0] f3;
            case(op)
                MUL: f3 = 0; MULH: f3 = 1; MULHSU: f3 = 2; MULHU: f3 = 3;
                DIV: f3 = 4; DIVU: f3 = 5; REM: f3 = 6; REMU: f3 = 7;
                default: f3 = 0;
            endcase
            if(word)
            begin
                case(op)
                    ADD:  return sext32(32'(a + b));
                    SUB:  return sext32(32'(a - b));
                    SLL:  return sext32(32'(a) << b[4:0]);
                    SRL:  return sext32(32'(a) >> b[4:0]);
                    SRA:  return sext32(32'($signed(32'(a)) >>> b[4:0]));
                    MUL:  return sext32(32'(a * b));
                    DIV, DIVU, REM, REMU: return csr.mul_div_w(f3, a[31:0], b[31:0]);
                    default: return '0;
                endcase
            end
            case(op)
                ADD:  return a + b;
                SUB:  return a - b;
                AND:  return a & b;
                OR:   return a | b;
                XOR:  return a ^ b;
                SLT:  return ($signed(a) < $signed(b)) ? 1 : 0;
                SLTU: return (a < b) ? 1 : 0;
                SLL:  return a << b[LOG_XL-1:0];
                SRL:  return a >> b[LOG_XL-1:0];
                SRA:  return x_t'($signed(a) >>> b[LOG_XL-1:0]);
                MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU: return csr.mul_div(f3, a, b);
                default: return '0;
            endcase
        endfunction:alu

        function automatic bit branch_taken(logic [2:0] f3, x_t a, x_t b);
            case(f3)
                3'b000: return a == b;
                3'b001: return a != b;
                3'b100: return $signed(a) <  $signed(b);
                3'b101: return $signed(a) >= $signed(b);
                3'b110: return a <  b;
                3'b111: return a >= b;
                default: return 0;
            endcase
        endfunction:branch_taken

        function automatic int unsigned access_size(logic [2:0] f3);
            return 1 << f3[1:0];
        endfunction:access_size

        // ── Reference model ─────────────────────────────────────────────────
        virtual function void write (execute_item t);
            execute_item exp;
            x_t pce, res_m, srca, wdata, srcb, a_alu, result, target, addr, tval, csr_rv, wv, src;
            logic [31:0] fa, fb, fres;
            logic ov, un, nan, inf, zr, inv;
            round_mode_t rm;
            bit taken, commit, exc, csr_exists, csr_unpred, irq, trap_taken, mret_taken, wr, minstret_written;
            int code, irq_code;
            iss_commit_t dummy;

            if(!t.rst)
            begin
                bubble(q);
                csr.reset();
                fres_issued = '0; stall_e_prev = 0;
            end

            // ── Operands (forwarding contract) ──────────────────────────────
            pce   = t.PCPlus4E - x_t'(4);
            res_m = (t.SelectorM == PCToReg) ? t.PCPlus4M : (t.SelectorM == CSRToReg) ? t.CsrOutM : t.ALUOutM;
            case(t.ForwardAE)
                3'b001: srca = t.ResultW;
                3'b010: srca = res_m;
                default: srca = t.RD1E;
            endcase
            case(t.ForwardBE)
                3'b001: wdata = t.ResultW;
                3'b010: wdata = res_m;
                default: wdata = t.RD2E;
            endcase
            srcb  = t.ALUSrcE ? t.SignImmE : wdata;
            a_alu = t.AuipcE ? pce : srca;
            result = alu(t.ALUControlE, a_alu, srcb, t.WordOpE);
            addr   = srca + t.SignImmE;

            // ── FPU (operands through the FP forwarding contract) ───────────
            case(t.ForwardFloatingAE)
                2'b01: fa = t.FPUOutW;
                2'b10: fa = t.FPUOutM;
                default: fa = t.RD1FE;
            endcase
            case(t.ForwardFloatingBE)
                2'b01: fb = t.FPUOutW;
                2'b10: fb = t.FPUOutM;
                default: fb = t.RD2FE;
            endcase
            if(t.MoveOperationE == RegToFPU) fa = srca[31:0];
            rm = (t.RoundModeE == DYN) ? round_mode_t'(csr.frm) : t.RoundModeE;
            flp_ref_compute(t.FPUControlE, rm, fa, fb, ov, un, nan, inf, zr, inv, fres);
            // The FPU takes its operands in the first cycle an FP instruction is
            // in EX; while it waits, forwarding sources may move on, so the
            // result is a function of the issue-cycle operands only.
            if(t.rst && t.ValidE && t.FPUValidE && !stall_e_prev) fres_issued = fres;
            fres = fres_issued;
            if(t.MoveOperationE == FPUToReg) result = sext32(fres);

            // ── Control flow ────────────────────────────────────────────────
            target = t.JalrE ? ((srca + t.SignImmE) & ~x_t'(1)) : t.PCBranchE;
            taken  = (t.BranchE && branch_taken(t.funct3E, srca, srcb)) || t.JumpE;

            // ── Synchronous exceptions (priority as in the Privileged spec) ─
            exc = 1; tval = '0;
            if(t.IllegaleInstructionE)                       code = 2;
            else if(taken && target[1])                      begin code = 0; tval = target; end
            else if(t.EbreakE)                               code = 3;
            else if(t.EcallE)                                code = 11;
            else if(t.MemReadE && ((addr & x_t'(access_size(t.funct3E) - 1)) != 0))  begin code = 4; tval = addr; end
            else if(t.MemWriteE && ((addr & x_t'(access_size(t.funct3E) - 1)) != 0)) begin code = 6; tval = addr; end
            else exc = 0;

            // ── CSR read and existence ──────────────────────────────────────
            csr.irq_ext = t.ExternalInterrupt; csr.irq_tmr = t.TimerInterrupt; csr.irq_sw = t.SoftwareInterrupt;
            csr.dut_csr_rdata = '0;
            csr_exists = csr.csr_read(t.CsrIndexE, csr_rv);
            csr_unpred = (t.CsrIndexE inside {mcycle, cycle, mcycleh, cycleh});
            if(t.CsrAccessE && !csr_exists)
            begin
                exc = 1; code = 2; tval = '0;                // unknown CSR -> illegal
            end

            // ── Interrupts (MEI > MSI > MTI), traps, MRET ───────────────────
            irq = csr.mstatus_mie && ((csr.mie_meie && t.ExternalInterrupt) ||
                                      (csr.mie_msie && t.SoftwareInterrupt) ||
                                      (csr.mie_mtie && t.TimerInterrupt));
            irq_code = (csr.mie_meie && t.ExternalInterrupt) ? 11 : (csr.mie_msie && t.SoftwareInterrupt) ? 3 : 7;
            commit     = t.ValidE && !t.StallE;
            trap_taken = commit && (irq || exc);
            mret_taken = commit && t.MRetE && !trap_taken;

            // ── Emit: registered shadow + combinational outputs ─────────────
            exp = execute_item::type_id::create("exp");
            exp.copy(q);
            if(shadow_inputs != null) exp.copy_inputs(shadow_inputs);
            exp.PCSrcE    = commit && taken && !trap_taken;
            exp.PCTargetE = target;
            exp.TrapIsSet = trap_taken || mret_taken;
            if(trap_taken)
            begin
                exp.CsrOutPC = {csr.mtvec[XL-1:2], 2'b00};
                if(irq && (csr.mtvec[1:0] == 2'b01))
                    exp.CsrOutPC = {csr.mtvec[XL-1:2], 2'b00} + x_t'(4 * irq_code);
            end
            else
                exp.CsrOutPC = csr.mepc;
            exp_port.write(exp);

            // ── EX/MEM register for the next edge ───────────────────────────
            if(t.rst)
            begin
                if(t.FlushM)
                    bubble(q);
                else if(!t.StallM)
                begin
                    q.ValidM = t.ValidE; q.RegWriteM = t.RegWriteE; q.SelectorM = t.SelectorE;
                    q.MemWriteM = t.MemWriteE; q.MemReadM = t.MemReadE; q.ALUOutM = result;
                    q.WriteDataM = wdata; q.RdM = t.RdE; q.funct3M = t.funct3E; q.PCPlus4M = t.PCPlus4E;
                    q.CsrOutM = csr_rv; q.chk_csrout = !csr_unpred;
                    q.RdFM = t.RdFE; q.FPUOutM = fres; q.FPURegWriteM = t.FPURegWriteE;
                    q.MoveOperationM = t.MoveOperationE;
                end

                // ── CSR state update at commit ──────────────────────────────
                minstret_written = 0;
                if(trap_taken)
                begin
                    csr.pc = pce;
                    csr.take_trap(dummy, irq, irq ? irq_code : code, (irq || (t.CsrAccessE && !csr_exists)) ? '0 : tval);
                end
                else if(mret_taken)
                begin
                    csr.mstatus_mie  = csr.mstatus_mpie;
                    csr.mstatus_mpie = 1;
                end
                else if(commit && t.CsrAccessE)
                begin
                    src = (t.CsrOperationE inside {csrrwi, csrrsi, csrrci}) ? x_t'(t.Rs1E) : srca;
                    wr  = (t.CsrOperationE inside {csrrw, csrrwi}) || (t.Rs1E != zero);
                    case(t.CsrOperationE)
                        csrrw, csrrwi: wv = src;
                        csrrs, csrrsi: wv = csr_rv | src;
                        default:       wv = csr_rv & ~src;
                    endcase
                    if(wr) minstret_written = csr.csr_write(t.CsrIndexE, wv);
                end
                if(commit && !trap_taken && !minstret_written)
                    csr.minstret = csr.minstret + 1;
            end

            stall_e_prev = t.rst && t.StallE;
            if(!$cast(shadow_inputs, t.clone()))
                `uvm_fatal("EXEC_PRED", "Failed to copy inputs to shadow - check for non-cloneable fields")
        endfunction:write

    endclass:execute_predictor

endpackage:execute_predictor_pkg
