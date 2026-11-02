// =============================================================================
// decode_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Decode stage, written from the ISA.
//
// The instruction is decoded from the RISC-V opcode/funct tables (RV32I or
// RV64I + M + the implemented F subset + Zicsr/SYSTEM), not from the RTL
// decoders, so a wrong decode, immediate, branch target or legality decision
// in the RTL shows up as a mismatch. The predictor also marks which ID/EX
// fields the instruction makes meaningful (chk_* on the expected item); an
// illegal instruction only has to be flagged illegal.
//
// Contract with the hazard unit that is checked as well: Rs1D/Rs2D read as x0
// when the instruction format has no rs1/rs2 field (LUI needs that for its
// zero operand).
//
// DUT decoupling (emit-before-update):
//   - *D outputs (Rs1D, Rs2D) are combinational on InstructionD.
//   - *E outputs are registered in the ID/EX register: the shadow emitted now
//     is the one computed on the previous call. FlushE loads a bubble, StallE
//     holds the register.
//
// Register-file timing: the register files write on the falling edge, so the
// value the ID/EX register latches at the next rising edge already contains
// this cycle's write-back; the write is applied before the next-cycle compute.
// =============================================================================
package decode_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import decode_item_pkg::*;
    import decode_reg_block_pkg::*;

    class decode_predictor extends uvm_subscriber #(decode_item);

        `uvm_component_utils(decode_predictor)

        localparam bit IS_RV64 = (FINAL_DATA_WIDTH == 64);
        localparam int XL = FINAL_DATA_WIDTH;

        function new (string name = "decode_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(decode_item) exp_port;
        decode_item q, exp_clone;            // q = ID/EX shadow (expected registered outputs)
        decode_item shadow_input;

        decode_reg_block reg_block;          // RAL mirror (integer + FP reg files)

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            q = decode_item::type_id::create("q");
            if(!uvm_config_db #(decode_reg_block)::get(this,"","REG_BLOCK",reg_block))
                `uvm_fatal("DECODE_PRED","predictor couldn't receive reg_block")
            reg_block.reset();
            bubble(q);
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reg_block.reset();
            bubble(q);
        endtask:reset_phase

        // ID/EX after reset or a flush: an invalid instruction with no side effect
        function void bubble(decode_item e);
            e.ValidE = 0; e.Rs1E = zero; e.Rs2E = zero; e.RdE = zero;
            e.RD1E = '0; e.RD2E = '0; e.SignImmE = '0; e.PCBranchE = '0; e.PCPlus4E = '0;
            e.funct3E = '0; e.ALUControlE = ADD; e.RegWriteE = 0; e.SelectorE = ALUToReg;
            e.MemWriteE = 0; e.MemReadE = 0; e.BranchE = 0; e.JumpE = 0; e.JalrE = 0;
            e.ALUSrcE = 0; e.AuipcE = 0; e.WordOpE = 0; e.CsrAccessE = 0;
            e.CsrOperationE = csrrw; e.CsrIndexE = mstatus;
            e.EcallE = 0; e.EbreakE = 0; e.MRetE = 0; e.IllegaleInstructionE = 0;
            e.RdFE = f0; e.Rs1FE = f0; e.Rs2FE = f0; e.RD1FE = '0; e.RD2FE = '0;
            e.FPUControlE = NOOPERATION; e.RoundModeE = RNE; e.FPURegWriteE = 0;
            e.MoveOperationE = FPUToFPU; e.FPUValidE = 0;
            // Only the side-effect controls (all zero) and ValidE matter
            e.chk_all = 1; e.chk_rs1 = 0; e.chk_rs2 = 0; e.chk_imm = 0; e.chk_tgt = 0;
            e.chk_alu = 0; e.chk_fp = 0; e.chk_csr = 0;
        endfunction:bubble

        function automatic logic [XL-1:0] sext(logic [XL-1:0] v, int bits);
            logic [XL-1:0] m = XL'(1) << (bits - 1);
            v = v & ((XL'(1) << bits) - 1);
            return (v ^ m) - m;
        endfunction:sext

        function void apply_wb(decode_item t);
            if(t.RegWriteW && (t.RdW != zero))
                void'(reg_block.gpr_rf.regs[int'(t.RdW)].predict(t.ResultW, .kind(UVM_PREDICT_WRITE)));
            if(t.FPURegWriteW)
                void'(reg_block.fpr_rf.regs[int'(t.RdFW)].predict(t.FPUOutW, .kind(UVM_PREDICT_WRITE)));
        endfunction:apply_wb

        // ── Rs1D / Rs2D contract: x0 when the format has no such field ──────
        function automatic gpr_t rs1_of(logic [31:0] in);
            opcode_t op = opcode_t'(in[6:0]);
            return (op inside {LUI, AUIPC, JAL}) ? zero : gpr_t'(in[19:15]);
        endfunction:rs1_of

        function automatic gpr_t rs2_of(logic [31:0] in);
            opcode_t op = opcode_t'(in[6:0]);
            return (op inside {R_TYPE, OP_32, S_TYPE, B_TYPE}) ? gpr_t'(in[24:20]) : zero;
        endfunction:rs2_of

        // ── Decode one instruction from the ISA tables into e ───────────────
        function void decode(decode_item t, decode_item e);
            logic [31:0] in = t.InstructionD;
            logic [6:0]  f7 = in[31:25];
            logic [2:0]  f3 = in[14:12];
            logic [4:0]  rs2f = in[24:20];
            logic [XL-1:0] pc = t.PCPlus4D - XL'(4);
            logic [XL-1:0] immI, immS, immB, immU, immJ;
            bit legal, wsh;

            immI = sext(XL'(in[31:20]), 12);
            immS = sext(XL'({in[31:25], in[11:7]}), 12);
            immB = sext(XL'({in[31], in[7], in[30:25], in[11:8], 1'b0}), 13);
            immU = sext(XL'({in[31:12], 12'b0}), 32);
            immJ = sext(XL'({in[31], in[19:12], in[20], in[30:21], 1'b0}), 21);

            bubble(e);
            e.ValidE  = t.ValidD;
            e.PCPlus4E = t.PCPlus4D;
            e.funct3E = f3;
            e.RdE     = gpr_t'(in[11:7]);
            e.Rs1E    = rs1_of(in);
            e.Rs2E    = rs2_of(in);
            e.RD1E    = signed'(reg_block.gpr_rf.regs[int'(e.Rs1E)].get_mirrored_value());
            e.RD2E    = signed'(reg_block.gpr_rf.regs[int'(e.Rs2E)].get_mirrored_value());
            e.Rs1FE   = fpr_t'(in[19:15]);
            e.Rs2FE   = fpr_t'(rs2f);
            e.RdFE    = fpr_t'(in[11:7]);
            e.RD1FE   = reg_block.fpr_rf.regs[int'(e.Rs1FE)].get_mirrored_value();
            e.RD2FE   = reg_block.fpr_rf.regs[int'(e.Rs2FE)].get_mirrored_value();
            e.RoundModeE = round_mode_t'(f3);
            e.CsrOperationE = csr_t'(f3);
            e.CsrIndexE = csr_index_t'(in[31:20]);
            e.chk_alu = 1;
            legal = 0;

            case(opcode_t'(in[6:0]))
                R_TYPE, OP_32: begin
                    wsh = (opcode_t'(in[6:0]) == OP_32);
                    e.RegWriteE = 1; e.WordOpE = wsh; e.chk_rs1 = 1; e.chk_rs2 = 1;
                    if(f7 == 7'b000_0000)
                    begin
                        legal = !wsh || (f3 inside {3'b000, 3'b001, 3'b101});
                        case(f3)
                            3'b000: e.ALUControlE = ADD;  3'b001: e.ALUControlE = SLL;
                            3'b010: e.ALUControlE = SLT;  3'b011: e.ALUControlE = SLTU;
                            3'b100: e.ALUControlE = XOR;  3'b101: e.ALUControlE = SRL;
                            3'b110: e.ALUControlE = OR;   3'b111: e.ALUControlE = AND;
                        endcase
                    end
                    else if(f7 == 7'b010_0000)
                    begin
                        legal = (f3 == 3'b000) || (f3 == 3'b101);
                        e.ALUControlE = (f3 == 3'b000) ? SUB : SRA;
                    end
                    else if(f7 == 7'b000_0001)
                    begin
                        legal = !wsh || (f3 inside {3'b000, 3'b100, 3'b101, 3'b110, 3'b111});
                        case(f3)
                            3'b000: e.ALUControlE = MUL;    3'b001: e.ALUControlE = MULH;
                            3'b010: e.ALUControlE = MULHSU; 3'b011: e.ALUControlE = MULHU;
                            3'b100: e.ALUControlE = DIV;    3'b101: e.ALUControlE = DIVU;
                            3'b110: e.ALUControlE = REM;    3'b111: e.ALUControlE = REMU;
                        endcase
                    end
                    if(wsh && !IS_RV64) legal = 0;
                end
                I_TYPE, OP_IMM_32: begin
                    wsh = (opcode_t'(in[6:0]) == OP_IMM_32);
                    e.RegWriteE = 1; e.ALUSrcE = 1; e.WordOpE = wsh; e.chk_rs1 = 1; e.chk_imm = 1;
                    e.SignImmE = immI;
                    case(f3)
                        3'b000: begin legal = 1; e.ALUControlE = ADD; end
                        3'b010: begin legal = !wsh; e.ALUControlE = SLT; end
                        3'b011: begin legal = !wsh; e.ALUControlE = SLTU; end
                        3'b100: begin legal = !wsh; e.ALUControlE = XOR; end
                        3'b110: begin legal = !wsh; e.ALUControlE = OR; end
                        3'b111: begin legal = !wsh; e.ALUControlE = AND; end
                        3'b001: begin
                            e.ALUControlE = SLL;
                            legal = (IS_RV64 && !wsh) ? (in[31:26] == 6'b0) : (in[31:25] == 7'b0);
                        end
                        3'b101: begin
                            if((IS_RV64 && !wsh) ? (in[31:26] == 6'b000000) : (in[31:25] == 7'b0000000))
                            begin legal = 1; e.ALUControlE = SRL; end
                            else if((IS_RV64 && !wsh) ? (in[31:26] == 6'b010000) : (in[31:25] == 7'b0100000))
                            begin legal = 1; e.ALUControlE = SRA; end
                        end
                    endcase
                    if(wsh && !IS_RV64) legal = 0;
                end
                LOAD: begin
                    e.RegWriteE = 1; e.MemReadE = 1; e.SelectorE = MemToReg; e.ALUSrcE = 1;
                    e.ALUControlE = ADD; e.chk_rs1 = 1; e.chk_imm = 1; e.SignImmE = immI;
                    legal = (f3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101}) ||
                            (IS_RV64 && (f3 inside {3'b011, 3'b110}));
                end
                S_TYPE: begin
                    e.MemWriteE = 1; e.ALUSrcE = 1; e.ALUControlE = ADD;
                    e.chk_rs1 = 1; e.chk_rs2 = 1; e.chk_imm = 1; e.SignImmE = immS;
                    legal = (f3 inside {3'b000, 3'b001, 3'b010}) || (IS_RV64 && (f3 == 3'b011));
                end
                B_TYPE: begin
                    e.BranchE = 1; e.chk_rs1 = 1; e.chk_rs2 = 1; e.chk_imm = 1; e.chk_tgt = 1;
                    e.SignImmE = immB; e.PCBranchE = pc + immB;
                    e.ALUControlE = (f3[2:1] == 2'b11) ? SLTU : SUB;
                    legal = !(f3 inside {3'b010, 3'b011});
                end
                JAL: begin
                    e.JumpE = 1; e.RegWriteE = 1; e.SelectorE = PCToReg; e.ALUSrcE = 1;
                    e.ALUControlE = ADD; e.chk_imm = 1; e.chk_tgt = 1;
                    e.SignImmE = immJ; e.PCBranchE = pc + immJ; legal = 1;
                end
                JALR: begin
                    e.JumpE = 1; e.JalrE = 1; e.RegWriteE = 1; e.SelectorE = PCToReg; e.ALUSrcE = 1;
                    e.ALUControlE = ADD; e.chk_rs1 = 1; e.chk_imm = 1; e.SignImmE = immI;
                    legal = (f3 == 3'b000);
                end
                LUI, AUIPC: begin
                    e.RegWriteE = 1; e.ALUSrcE = 1; e.ALUControlE = ADD; e.AuipcE = (opcode_t'(in[6:0]) == AUIPC);
                    e.chk_rs1 = 1; e.chk_imm = 1; e.chk_tgt = 1;     // LUI: operand A must read x0
                    e.SignImmE = immU; e.PCBranchE = pc + immU; legal = 1;
                end
                MISC_MEM: begin
                    e.chk_alu = 0;
                    legal = (f3 == 3'b000);                         // FENCE; FENCE.I not claimed
                end
                CSR: begin
                    e.chk_alu = 0;
                    if(f3 == 3'b000)
                    begin
                        if(in[19:7] == '0)
                            case(in[31:20])
                                12'h000: begin legal = 1; e.EcallE = 1; end
                                12'h001: begin legal = 1; e.EbreakE = 1; end
                                12'h302: begin legal = 1; e.MRetE = 1; end
                                12'h105: legal = 1;                 // WFI = NOP
                            endcase
                    end
                    else if(f3 != 3'b100)
                    begin
                        e.CsrAccessE = 1; e.RegWriteE = 1; e.SelectorE = CSRToReg;
                        e.chk_rs1 = 1; e.chk_csr = 1;
                        // A write to the read-only space (csr[11:10] == 2'b11) is illegal
                        legal = !((in[31:30] == 2'b11) && ((f3[1:0] == 2'b01) || (in[19:15] != 0)));
                    end
                end
                FLOATING_PT: begin
                    e.chk_alu = 0; e.chk_fp = 1;
                    legal = fp_decode(in, e);
                    if(e.MoveOperationE == RegToFPU) e.chk_rs1 = 1;
                end
                default: legal = 0;
            endcase

            e.IllegaleInstructionE = !legal;
            if(!legal)
                e.chk_all = 0;                              // only the illegal flag matters
        endfunction:decode

        // OP-FP (single): returns 1 for a legal encoding
        function bit fp_decode(logic [31:0] in, decode_item e);
            logic [6:0] f7 = in[31:25];
            logic [2:0] f3 = in[14:12];
            logic [4:0] rs2f = in[24:20];
            bit uses_rm = 0;
            e.FPUControlE = NOOPERATION;
            case(f7)
                7'b000_0000: begin e.FPUControlE = FADD_S; e.FPURegWriteE = 1; uses_rm = 1; end
                7'b000_0100: begin e.FPUControlE = FSUB_S; e.FPURegWriteE = 1; uses_rm = 1; end
                7'b000_1000: begin e.FPUControlE = FMUL_S; e.FPURegWriteE = 1; uses_rm = 1; end
                7'b000_1100: begin e.FPUControlE = FDIV_S; e.FPURegWriteE = 1; uses_rm = 1; end
                7'b010_1100: if(rs2f == 0) begin e.FPUControlE = FSQRT_S; e.FPURegWriteE = 1; uses_rm = 1; end
                7'b001_0000: case(f3)
                                 3'b000: begin e.FPUControlE = FSGNJ_S;  e.FPURegWriteE = 1; end
                                 3'b001: begin e.FPUControlE = FSGNJN_S; e.FPURegWriteE = 1; end
                                 3'b010: begin e.FPUControlE = FSGNJX_S; e.FPURegWriteE = 1; end
                             endcase
                7'b001_0100: case(f3)
                                 3'b000: begin e.FPUControlE = FMIN_S; e.FPURegWriteE = 1; end
                                 3'b001: begin e.FPUControlE = FMAX_S; e.FPURegWriteE = 1; end
                             endcase
                7'b110_0000: if(rs2f inside {0, 1})
                             begin
                                 e.FPUControlE = rs2f[0] ? FCVT_WU_S : FCVT_W_S;
                                 e.RegWriteE = 1; e.MoveOperationE = FPUToReg; uses_rm = 1;
                             end
                7'b111_0000: if(rs2f == 0)
                                 case(f3)
                                     3'b000: begin e.FPUControlE = FMV_X_S;  e.RegWriteE = 1; e.MoveOperationE = FPUToReg; end
                                     3'b001: begin e.FPUControlE = FCLASS_S; e.RegWriteE = 1; e.MoveOperationE = FPUToReg; end
                                 endcase
                7'b101_0000: case(f3)                     // compares write the integer rd
                                 3'b010: begin e.FPUControlE = FEQ_S; e.RegWriteE = 1; e.MoveOperationE = FPUToReg; end
                                 3'b001: begin e.FPUControlE = FLT_S; e.RegWriteE = 1; e.MoveOperationE = FPUToReg; end
                                 3'b000: begin e.FPUControlE = FLE_S; e.RegWriteE = 1; e.MoveOperationE = FPUToReg; end
                             endcase
                7'b110_1000: if(rs2f inside {0, 1})
                             begin
                                 e.FPUControlE = rs2f[0] ? FCVT_S_WU : FCVT_S_W;
                                 e.FPURegWriteE = 1; e.MoveOperationE = RegToFPU; uses_rm = 1;
                             end
                7'b111_1000: if((rs2f == 0) && (f3 == 3'b000))
                             begin
                                 e.FPUControlE = FMV_S_X; e.FPURegWriteE = 1; e.MoveOperationE = RegToFPU;
                             end
            endcase
            if(e.FPUControlE == NOOPERATION)
                return 0;
            if(uses_rm && ((f3 == 3'b101) || (f3 == 3'b110)))
                return 0;                                   // reserved rounding mode
            e.FPUValidE = 1;
            return 1;
        endfunction:fp_decode

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (decode_item t);
            decode_item exp;
            if(!t.rst)
            begin
                bubble(q);
                reg_block.reset();
            end

            // Emit: combinational *D outputs now, registered *E from the shadow
            exp = decode_item::type_id::create("exp");
            exp.copy(q);
            exp.Rs1D = rs1_of(t.InstructionD);
            exp.Rs2D = rs2_of(t.InstructionD);
            if(shadow_input != null)
                exp.copy_inputs(shadow_input);
            exp_port.write(exp);

            // Update the shadow for the next rising edge
            if(t.rst)
            begin
                apply_wb(t);
                if(t.FlushE)
                    bubble(q);
                else if(!t.StallE)
                    decode(t, q);
            end
            if(!$cast(shadow_input, t.clone()))
                `uvm_fatal("DECODE_PRED", "Failed to cast shadow input - check for type mismatches")
        endfunction:write

    endclass:decode_predictor

endpackage:decode_predictor_pkg
