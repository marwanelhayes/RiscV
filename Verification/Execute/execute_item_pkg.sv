// =============================================================================
// execute_item_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage sequence item package for UVM verification.
//
// Stimulus is drawn per instruction kind, and the EX control fields of each
// kind follow the decode contract (which the Decode env checks against the
// ISA), so the execute stage is exercised the way decode can drive it. The
// data fields are random with a bias toward aligned addresses and the
// arithmetic corner values. Compare masks (chk_*) on the expected item drop
// fields whose value is not architecturally defined (e.g. a counter read).
// =============================================================================
package execute_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    typedef enum {K_BUBBLE, K_ALU, K_ALUI, K_W, K_WI, K_LOAD, K_STORE, K_BRANCH, K_JAL, K_JALR,
                  K_LUI, K_AUIPC, K_CSR, K_ECALL, K_EBREAK, K_MRET, K_ILLEGAL, K_NOP, K_FP} ex_kind_t;

    class execute_item extends uvm_sequence_item;

        `uvm_object_utils(execute_item)

        function new (string name = "execute_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand ex_kind_t kind;
        rand logic                                ValidE;
        rand logic signed [FINAL_DATA_WIDTH-1:0]  RD1E;
        rand logic signed [FINAL_DATA_WIDTH-1:0]  RD2E;
        rand logic signed [FINAL_DATA_WIDTH-1:0]  SignImmE;
        rand logic [FINAL_DATA_WIDTH-1:0]         PCPlus4E;
        rand logic [FINAL_DATA_WIDTH-1:0]         PCBranchE;
        rand alu_operation_t                      ALUControlE;
        rand logic [2:0]                          funct3E;
        rand logic                                BranchE;
        rand logic                                JumpE;
        rand logic                                JalrE;
        rand logic                                AuipcE;
        rand logic                                WordOpE;
        rand logic [2:0]                          ForwardAE;
        rand logic [2:0]                          ForwardBE;
        rand gpr_t                                Rs1E;
        rand gpr_t                                RdE;
        rand logic                                RegWriteE;
        rand logic                                CsrAccessE;
        rand csr_t                                CsrOperationE;
        rand csr_index_t                          CsrIndexE;
        rand selector_t                           SelectorE;
        rand logic                                ALUSrcE;
        rand logic                                MemWriteE;
        rand logic                                MemReadE;
        rand logic                                MRetE;
        rand logic                                EcallE;
        rand logic                                EbreakE;
        rand logic                                IllegaleInstructionE;
        rand fpr_t                                RdFE;
        rand logic [FINAL_FLP_WIDTH-1:0]          RD1FE;
        rand logic [FINAL_FLP_WIDTH-1:0]          RD2FE;
        rand fpu_operation_t                      FPUControlE;
        rand round_mode_t                         RoundModeE;
        rand logic                                FPURegWriteE;
        rand logic                                FPUValidE;
        rand move_operation_t                     MoveOperationE;
        rand logic [1:0]                          ForwardFloatingAE;
        rand logic [1:0]                          ForwardFloatingBE;
        rand fpr_t                                Rs1FE;
        rand fpr_t                                Rs2FE;
        rand logic signed [FINAL_DATA_WIDTH-1:0]  ResultW;
        rand logic [FINAL_FLP_WIDTH-1:0]          FPUOutW;
        rand logic                                TimerInterrupt;
        rand logic                                ExternalInterrupt;
        rand logic                                SoftwareInterrupt;
        rand logic                                MemStallBit;
        logic                                     StallE;
        logic                                     StallM;
        logic                                     FlushM;
        logic                                     ValidM;
        logic signed [FINAL_DATA_WIDTH-1:0]       ALUOutM;
        logic signed [FINAL_DATA_WIDTH-1:0]       WriteDataM;
        gpr_t                                     RdM;
        logic                                     PCSrcE;
        logic [FINAL_DATA_WIDTH-1:0]              PCTargetE;
        logic                                     RegWriteM;
        logic [FINAL_DATA_WIDTH-1:0]              PCPlus4M;
        selector_t                                SelectorM;
        logic [2:0]                               funct3M;
        logic [FINAL_DATA_WIDTH-1:0]              CsrOutM;
        logic                                     MemWriteM;
        logic                                     MemReadM;
        logic                                     TrapIsSet;
        logic [FINAL_DATA_WIDTH-1:0]              CsrOutPC;
        fpr_t                                     RdFM;
        logic                                     OverflowM;
        logic                                     UnderflowM;
        logic                                     NaNM;
        logic                                     InfM;
        logic                                     ZeroM;
        logic                                     InvalidDivM;
        logic [FINAL_FLP_WIDTH-1:0]               FPUOutM;
        logic                                     FPURegWriteM;
        move_operation_t                          MoveOperationM;
        logic                                     FPUBusyE;
        logic                                     FPUDoneE;

        // ── Compare masks (set by the predictor on the expected item) ───────
        bit chk_csrout = 1;   // CsrOutM is predictable (not a cycle-counter read)

        localparam bit IS_RV64 = (FINAL_DATA_WIDTH == 64);

        constraint LowResetProb { rst dist {0:=2, 1:=1000}; }
        constraint FreezeProb   { MemStallBit dist {0:=85, 1:=15}; }
        constraint IrqProb
        {
            TimerInterrupt    dist {0:=95, 1:=5};
            ExternalInterrupt dist {0:=97, 1:=3};
            SoftwareInterrupt dist {0:=97, 1:=3};
        }
        constraint KindProb
        {
            kind dist {K_BUBBLE := 5, K_ALU := 14, K_ALUI := 10, K_W := 5, K_WI := 4, K_LOAD := 9,
                       K_STORE := 9, K_BRANCH := 10, K_JAL := 4, K_JALR := 5, K_LUI := 3, K_AUIPC := 3,
                       K_CSR := 9, K_ECALL := 1, K_EBREAK := 1, K_MRET := 2, K_ILLEGAL := 1, K_NOP := 1, K_FP := 8};
            !IS_RV64 -> !(kind inside {K_W, K_WI});
        }
        constraint Forwarding
        {
            ForwardAE inside {3'b000, 3'b001, 3'b010};       // RF, WB, MEM (hazard_unit codes)
            ForwardBE inside {3'b000, 3'b001, 3'b010};
            ForwardFloatingAE inside {2'b00, 2'b01, 2'b10};
            ForwardFloatingBE inside {2'b00, 2'b01, 2'b10};
        }
        // Aligned addresses dominate; misaligned ones still occur (they trap)
        constraint Alignment
        {
            RD1E[2:0] dist {3'b000 := 80, [3'b001:3'b111] := 20};
            SignImmE[2:0] dist {3'b000 := 80, [3'b001:3'b111] := 20};
            PCPlus4E[1:0] == 2'b00;
            PCBranchE[0] == 1'b0;
            PCBranchE[1] dist {1'b0 := 90, 1'b1 := 10};      // a misaligned target traps when taken
        }
        constraint Csr
        {
            CsrIndexE inside {fflags, frm, fcsr, mstatus, misa, medeleg, mideleg, mie, mtvec, mscratch,
                              mepc, mcause, mtval, mip, mstatush, mcycle, minstret, mcycleh, minstreth,
                              cycle, instret, cycleh, instreth, mvendorid, marchid, mimpid, mhartid,
                              csr_index_t'(12'hB03), csr_index_t'(12'h323), csr_index_t'(12'h7C0), csr_index_t'(12'h180)};
            CsrOperationE inside {csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci};
            // frm keeps a valid rounding mode (an invalid dynamic frm is a known B9.1 gap)
            (CsrAccessE && (CsrIndexE inside {frm, fcsr})) -> (CsrOperationE inside {csrrs, csrrc}) && (Rs1E == zero);
        }
        // EX controls per kind, as the decoder produces them
        constraint Controls
        {
            ValidE == (kind != K_BUBBLE);
            BranchE  == (kind == K_BRANCH);
            JumpE    == (kind inside {K_JAL, K_JALR});
            JalrE    == (kind == K_JALR);
            AuipcE   == (kind == K_AUIPC);
            WordOpE  == (kind inside {K_W, K_WI});
            MemReadE == (kind == K_LOAD);
            MemWriteE == (kind == K_STORE);
            CsrAccessE == (kind == K_CSR);
            EcallE   == (kind == K_ECALL);
            EbreakE  == (kind == K_EBREAK);
            MRetE    == (kind == K_MRET);
            IllegaleInstructionE == (kind == K_ILLEGAL);
            FPUValidE == (kind == K_FP);
            RegWriteE == ((kind inside {K_ALU, K_ALUI, K_W, K_WI, K_LOAD, K_JAL, K_JALR, K_LUI, K_AUIPC, K_CSR}) ||
                          ((kind == K_FP) && (MoveOperationE == FPUToReg)));
            FPURegWriteE == ((kind == K_FP) && (MoveOperationE != FPUToReg));
            ALUSrcE == (kind inside {K_ALUI, K_WI, K_LOAD, K_STORE, K_JAL, K_JALR, K_LUI, K_AUIPC});
            SelectorE == ((kind == K_LOAD) ? MemToReg : (kind inside {K_JAL, K_JALR}) ? PCToReg :
                          (kind == K_CSR) ? CSRToReg : ALUToReg);
            (kind inside {K_LOAD, K_STORE, K_JAL, K_JALR, K_LUI, K_AUIPC, K_BUBBLE, K_NOP,
                          K_CSR, K_ECALL, K_EBREAK, K_MRET, K_ILLEGAL, K_FP}) -> ALUControlE == ADD;
            (kind == K_BRANCH) -> (ALUControlE == ((funct3E[2:1] == 2'b11) ? SLTU : SUB));
            (kind == K_BRANCH) -> !(funct3E inside {3'b010, 3'b011});
            (kind == K_LOAD)   -> (funct3E inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101}) ||
                                  (IS_RV64 && (funct3E inside {3'b011, 3'b110}));
            (kind == K_STORE)  -> (funct3E inside {3'b000, 3'b001, 3'b010}) || (IS_RV64 && (funct3E == 3'b011));
            (kind == K_W)      -> (ALUControlE inside {ADD, SUB, SLL, SRL, SRA, MUL, DIV, DIVU, REM, REMU});
            (kind == K_WI)     -> (ALUControlE inside {ADD, SLL, SRL, SRA});
            (kind == K_ALUI)   -> !(ALUControlE inside {SUB, MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU});
            (kind == K_LUI)    -> (Rs1E == zero) && (ForwardAE == 3'b000) && (RD1E == 0);
            (kind == K_BUBBLE) -> (RdE == zero) && (Rs1E == zero);
            (kind != K_FP)     -> (FPUControlE == NOOPERATION) && (MoveOperationE == FPUToFPU);
            (kind == K_FP)     -> (FPUControlE != NOOPERATION);
            (kind == K_FP) && (FPUControlE inside {FCVT_W_S, FCVT_WU_S, FMV_X_S, FEQ_S, FLT_S, FLE_S, FCLASS_S}) -> MoveOperationE == FPUToReg;
            (kind == K_FP) && (FPUControlE inside {FCVT_S_W, FCVT_S_WU, FMV_S_X}) -> MoveOperationE == RegToFPU;
            (kind == K_FP) && !(FPUControlE inside {FCVT_W_S, FCVT_WU_S, FMV_X_S, FEQ_S, FLT_S, FLE_S, FCLASS_S,
                                                    FCVT_S_W, FCVT_S_WU, FMV_S_X}) -> MoveOperationE == FPUToFPU;
            RoundModeE inside {RNE, RTZ, RDN, RUP, RMM, DYN};
        }

        virtual function string convert2str();
            return $sformatf("Inputs: rst=%0d kind=%s ValidE=%0d StallE=%0d StallM=%0d FlushM=%0d ALU=%s W=%0d A=%0h B=%0h Imm=%0h FwdA=%0d FwdB=%0d f3=%0d PC+4=%0h PCBr=%0h Br=%0d J=%0d Jalr=%0d Csr=%0d %s %s Rs1=%s FP=%s Mv=%s
            Outputs: ValidM=%0d ALUOutM=%0h WriteDataM=%0h RdM=%s RegWriteM=%0d MemR/W=%0d/%0d PCSrcE=%0d PCTargetE=%0h TrapIsSet=%0d CsrOutPC=%0h CsrOutM=%0h FPUOutM=%0h FPURegWriteM=%0d RdFM=%s Done=%0d",
            rst, kind.name(), ValidE, StallE, StallM, FlushM, ALUControlE.name(), WordOpE, RD1E, RD2E, SignImmE, ForwardAE, ForwardBE,
            funct3E, PCPlus4E, PCBranchE, BranchE, JumpE, JalrE, CsrAccessE, CsrOperationE.name(), CsrIndexE.name(), Rs1E.name(),
            FPUControlE.name(), MoveOperationE.name(),
            ValidM, ALUOutM, WriteDataM, RdM.name(), RegWriteM, MemReadM, MemWriteM, PCSrcE, PCTargetE, TrapIsSet, CsrOutPC,
            CsrOutM, FPUOutM, FPURegWriteM, RdFM.name(), FPUDoneE);
        endfunction:convert2str

        function bit chk(string name, logic [63:0] act, logic [63:0] exp);
            if(act !== exp)
            begin
                `uvm_info({name, " Mismatch"}, $sformatf("Expected: %0h Actual: %0h", exp, act), UVM_LOW)
                return 1'b0;
            end
            return 1'b1;
        endfunction:chk

        // this = actual, rhs = expected
        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            execute_item e;
            bit ok;
            if(!$cast(e, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not an execute_item")
                return 1'b0;
            end
            ok = super.do_compare(rhs, comparer);
            // Combinational EX outputs
            ok &= chk("PCSrcE", PCSrcE, e.PCSrcE) & chk("TrapIsSet", TrapIsSet, e.TrapIsSet);
            if(e.PCSrcE)    ok &= chk("PCTargetE", PCTargetE, e.PCTargetE);
            if(e.TrapIsSet) ok &= chk("CsrOutPC", CsrOutPC, e.CsrOutPC);
            // EX/MEM register
            ok &= chk("ValidM", ValidM, e.ValidM) & chk("RegWriteM", RegWriteM, e.RegWriteM);
            ok &= chk("MemWriteM", MemWriteM, e.MemWriteM) & chk("MemReadM", MemReadM, e.MemReadM);
            ok &= chk("FPURegWriteM", FPURegWriteM, e.FPURegWriteM);
            if(e.ValidM)
            begin
                ok &= chk("RdM", RdM, e.RdM) & chk("SelectorM", SelectorM, e.SelectorM);
                ok &= chk("funct3M", funct3M, e.funct3M) & chk("PCPlus4M", PCPlus4M, e.PCPlus4M);
                // ALU result of ALU/FP->int instructions, address of loads/stores
                if((e.RegWriteM && (e.SelectorM == ALUToReg)) || e.MemReadM || e.MemWriteM)
                    ok &= chk("ALUOutM", ALUOutM, e.ALUOutM);
                if(e.MemWriteM)
                    ok &= chk("WriteDataM", WriteDataM, e.WriteDataM);
                if((e.SelectorM == CSRToReg) && e.chk_csrout)
                    ok &= chk("CsrOutM", CsrOutM, e.CsrOutM);
                if(e.FPURegWriteM)
                    ok &= chk("RdFM", RdFM, e.RdFM) & chk("FPUOutM", FPUOutM, e.FPUOutM);
            end
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            execute_item o;
            if(!$cast(o, rhs))
            begin
                `uvm_fatal("do_copy","rhs is not an execute_item")
                return;
            end
            super.do_copy(rhs);
            copy_inputs(rhs);
            this.StallE = o.StallE;
            this.StallM = o.StallM;
            this.FlushM = o.FlushM;
            this.ValidM = o.ValidM;
            this.ALUOutM = o.ALUOutM;
            this.WriteDataM = o.WriteDataM;
            this.RdM = o.RdM;
            this.PCSrcE = o.PCSrcE;
            this.PCTargetE = o.PCTargetE;
            this.RegWriteM = o.RegWriteM;
            this.PCPlus4M = o.PCPlus4M;
            this.SelectorM = o.SelectorM;
            this.funct3M = o.funct3M;
            this.CsrOutM = o.CsrOutM;
            this.MemWriteM = o.MemWriteM;
            this.MemReadM = o.MemReadM;
            this.TrapIsSet = o.TrapIsSet;
            this.CsrOutPC = o.CsrOutPC;
            this.RdFM = o.RdFM;
            this.OverflowM = o.OverflowM;
            this.UnderflowM = o.UnderflowM;
            this.NaNM = o.NaNM;
            this.InfM = o.InfM;
            this.ZeroM = o.ZeroM;
            this.InvalidDivM = o.InvalidDivM;
            this.FPUOutM = o.FPUOutM;
            this.FPURegWriteM = o.FPURegWriteM;
            this.MoveOperationM = o.MoveOperationM;
            this.FPUBusyE = o.FPUBusyE;
            this.FPUDoneE = o.FPUDoneE;
            this.chk_csrout = o.chk_csrout;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            execute_item o;
            if(!$cast(o, rhs))
            begin
                `uvm_fatal("copy_inputs","rhs is not an execute_item")
                return;
            end
            this.rst = o.rst;
            this.kind = o.kind;
            this.ValidE = o.ValidE;
            this.RD1E = o.RD1E;
            this.RD2E = o.RD2E;
            this.SignImmE = o.SignImmE;
            this.PCPlus4E = o.PCPlus4E;
            this.PCBranchE = o.PCBranchE;
            this.ALUControlE = o.ALUControlE;
            this.funct3E = o.funct3E;
            this.BranchE = o.BranchE;
            this.JumpE = o.JumpE;
            this.JalrE = o.JalrE;
            this.AuipcE = o.AuipcE;
            this.WordOpE = o.WordOpE;
            this.ForwardAE = o.ForwardAE;
            this.ForwardBE = o.ForwardBE;
            this.Rs1E = o.Rs1E;
            this.RdE = o.RdE;
            this.RegWriteE = o.RegWriteE;
            this.CsrAccessE = o.CsrAccessE;
            this.CsrOperationE = o.CsrOperationE;
            this.CsrIndexE = o.CsrIndexE;
            this.SelectorE = o.SelectorE;
            this.ALUSrcE = o.ALUSrcE;
            this.MemWriteE = o.MemWriteE;
            this.MemReadE = o.MemReadE;
            this.MRetE = o.MRetE;
            this.EcallE = o.EcallE;
            this.EbreakE = o.EbreakE;
            this.IllegaleInstructionE = o.IllegaleInstructionE;
            this.RdFE = o.RdFE;
            this.RD1FE = o.RD1FE;
            this.RD2FE = o.RD2FE;
            this.FPUControlE = o.FPUControlE;
            this.RoundModeE = o.RoundModeE;
            this.FPURegWriteE = o.FPURegWriteE;
            this.FPUValidE = o.FPUValidE;
            this.MoveOperationE = o.MoveOperationE;
            this.ForwardFloatingAE = o.ForwardFloatingAE;
            this.ForwardFloatingBE = o.ForwardFloatingBE;
            this.Rs1FE = o.Rs1FE;
            this.Rs2FE = o.Rs2FE;
            this.ResultW = o.ResultW;
            this.FPUOutW = o.FPUOutW;
            this.TimerInterrupt = o.TimerInterrupt;
            this.ExternalInterrupt = o.ExternalInterrupt;
            this.SoftwareInterrupt = o.SoftwareInterrupt;
            this.MemStallBit = o.MemStallBit;
        endfunction:copy_inputs

    endclass:execute_item

endpackage:execute_item_pkg
