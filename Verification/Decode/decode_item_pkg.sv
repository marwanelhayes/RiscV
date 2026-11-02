// =============================================================================
// decode_item_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage sequence item package for UVM verification.
//
// Stimulus: most instructions are drawn from the opcode spaces the core
// claims, with every other field random, so reserved funct3/funct7/rs2/rm
// values (illegal encodings) appear naturally; a share is fully random bits.
//
// Checking: the predictor marks which ID/EX fields are architecturally
// meaningful for the decoded instruction (chk_* flags on the expected item).
// Fields that the ISA leaves free for an instruction (e.g. rs2 of an I-type,
// or everything but the illegal flag of an illegal instruction) are not
// compared, so the check judges the decode, not a copy of the RTL.
// =============================================================================
package decode_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class decode_item extends uvm_sequence_item;

        // ── Inputs ──────────────────────────────────────────────────────────
        rand logic rst;
        logic [FINAL_DATA_WIDTH-1:0] PCPlus4D = 0;
        rand logic [INSTR_WIDTH-1:0] InstructionD;
        rand logic ValidD;
        rand gpr_t RdW;
        rand logic FlushE;
        rand logic StallE;
        rand logic RegWriteW;
        rand logic signed [FINAL_DATA_WIDTH-1:0] ResultW;
        rand fpr_t RdFW;
        rand logic [FINAL_FLP_WIDTH-1:0] FPUOutW;
        rand logic FPURegWriteW;
        rand bit legalish;                       // draw from the claimed opcode spaces

        // ── Outputs ─────────────────────────────────────────────────────────
        gpr_t Rs1E;
        gpr_t Rs2E;
        gpr_t Rs1D;
        gpr_t Rs2D;
        gpr_t RdE;
        logic ValidE;
        logic JumpE;
        logic JalrE;
        alu_operation_t ALUControlE;
        csr_t CsrOperationE;
        logic signed [FINAL_DATA_WIDTH-1:0] RD1E;
        logic signed [FINAL_DATA_WIDTH-1:0] RD2E;
        logic signed [FINAL_DATA_WIDTH-1:0] SignImmE;
        logic [FINAL_DATA_WIDTH-1:0] PCBranchE;
        csr_index_t CsrIndexE;
        logic [2:0] funct3E;
        logic [FINAL_DATA_WIDTH-1:0] PCPlus4E;
        logic RegWriteE;
        selector_t SelectorE;
        logic MemWriteE;
        logic MemReadE;
        logic BranchE;
        logic CsrAccessE;
        logic ALUSrcE;
        logic AuipcE;
        logic WordOpE;
        logic EcallE;
        logic EbreakE;
        logic MRetE;
        logic IllegaleInstructionE;
        fpr_t RdFE;
        logic [FINAL_FLP_WIDTH-1:0] RD1FE;
        logic [FINAL_FLP_WIDTH-1:0] RD2FE;
        fpu_operation_t FPUControlE;
        round_mode_t RoundModeE;
        logic FPURegWriteE;
        move_operation_t MoveOperationE;
        fpr_t Rs1FE;
        fpr_t Rs2FE;
        logic FPUValidE;
        opcode_t opcode;

        // ── Compare masks (set by the predictor on the expected item) ───────
        bit chk_all = 1;      // 0: only ValidE / PCPlus4E / IllegaleInstructionE matter (bubble or illegal)
        bit chk_rs1 = 1;      // instruction reads rs1 (index and value)
        bit chk_rs2 = 1;      // instruction reads rs2 (index and value)
        bit chk_imm = 1;      // instruction has an immediate
        bit chk_tgt = 1;      // PCBranchE (= PC + imm) is meaningful
        bit chk_alu = 1;      // ALUControlE is meaningful
        bit chk_fp  = 1;      // FP fields are meaningful
        bit chk_csr = 1;      // CSR fields are meaningful

        //Register the class in the factory
        `uvm_object_utils(decode_item)

        //Overriding the build in constructor with the child class
        function new (string name = "decode_item");
            super.new(name);
        endfunction: new

        //Insert random resets at random times
        constraint LowResetProb { rst dist {0:=5,1:=200}; }
        constraint ValidProb    { ValidD dist {0:=10,1:=90}; }
        // Fetch contract: an IF/ID bubble always carries the NOP (ADDI x0, x0, 0)
        constraint BubbleIsNop  { !ValidD -> (InstructionD == 32'h0000_0013); }
        constraint StallProb    { StallE dist {0:=85,1:=15}; }
        constraint LegalProb    { legalish dist {0:=15,1:=85}; }

        // Claimed opcode spaces (the RV64-only ones are illegal at XLEN = 32,
        // which the predictor knows); the remaining fields stay random.
        constraint ClaimedOpcodes
        {
            legalish -> opcode_t'(InstructionD[6:0]) inside {R_TYPE, I_TYPE, S_TYPE, B_TYPE, LOAD, JAL, JALR,
                                                            LUI, AUIPC, MISC_MEM, OP_IMM_32, OP_32, CSR, FLOATING_PT};
        }
        // Bias the sub-fields toward their legal values so legal decodes dominate
        constraint MostlyLegalFields
        {
            if(legalish && (opcode_t'(InstructionD[6:0]) inside {R_TYPE, OP_32}))
                InstructionD[31:25] dist {7'b000_0000 := 40, 7'b010_0000 := 20, 7'b000_0001 := 30, [7'h02:7'h1F] := 10};
            if(legalish && (opcode_t'(InstructionD[6:0]) == CSR) && (InstructionD[14:12] == 3'b000))
                InstructionD[31:20] dist {12'h000 := 25, 12'h001 := 25, 12'h302 := 25, 12'h105 := 10, [12'h003:12'hFFF] := 15};
            if(legalish && (opcode_t'(InstructionD[6:0]) == CSR) && (InstructionD[14:12] == 3'b000))
                InstructionD[19:7] dist {13'h0 := 85, [13'h1:13'h1FFF] := 15};
            if(legalish && (opcode_t'(InstructionD[6:0]) == FLOATING_PT))
                InstructionD[31:25] inside {7'b000_0000, 7'b000_0100, 7'b000_1000, 7'b000_1100, 7'b010_1100,
                                            7'b001_0000, 7'b001_0100, 7'b110_0000, 7'b111_0000, 7'b101_0000,
                                            7'b110_1000, 7'b111_1000, 7'b111_1111};
            if(legalish && (opcode_t'(InstructionD[6:0]) == FLOATING_PT))
                InstructionD[24:20] dist {5'd0 := 50, 5'd1 := 20, [5'd2:5'd31] := 30};
        }

        //Forbid writing to zero register
        constraint NoZeroReg { !(RdW inside{zero}); }

        //Insert random flushes at random times
        constraint FlushEProb { FlushE dist {0:=80,1:=20}; }

        virtual function string convert2str();
            opcode = opcode_t'(InstructionD[6:0]);
            return $sformatf("\tInputs: rst = %0d | PCPlus4D = %0h | Opcode = %s | InstructionD = %0h | ValidD = %0d | RdW = %s | FlushE = %0d | StallE = %0d | RegWriteW = %0d | ResultW = %0h | RdFW = %s | FPUOutW = %0h | FPURegWriteW = %0d \n
            Outputs: ValidE = %0d | Rs1E = %s | Rs2E = %s | Rs1D = %s | Rs2D = %s | RdE = %s | JumpE = %0h | JalrE = %0h | ALUControlE = %s | 
            CsrOperationE = %s | RD1E = %0h | RD2E = %0h | SignImmE = %0h | PCBranchE = %0h | CsrIndexE = %s | 
            funct3E = %0h | PCPlus4E = %0h | RegWriteE = %0h | SelectorE = %s | MemWriteE = %0h | MemReadE = %0h | BranchE = %0h | 
            CsrAccessE = %0h | ALUSrcE = %0h | AuipcE = %0h | WordOpE = %0h | EcallE = %0h | EbreakE = %0h | MRetE =  %0h | IllegaleInstructionE = %0h |
            RdFE = %s | RD1FE = %0h | RD2FE = %0h | FPUControlE = %s | RoundModeE %s | FPURegWriteE = %0h | 
            MoveOperationE = %s | Rs1FE = %s | Rs2FE = %s | FPUValidE = %0h",
            rst,PCPlus4D,opcode.name(),InstructionD,ValidD,RdW.name(),FlushE,StallE,RegWriteW,ResultW,RdFW.name(),FPUOutW,FPURegWriteW,
            ValidE, Rs1E.name(), Rs2E.name(), Rs1D.name(), Rs2D.name(), RdE.name(), JumpE, JalrE, ALUControlE.name(), CsrOperationE.name(),
            RD1E, RD2E, SignImmE, PCBranchE, CsrIndexE.name(), funct3E, PCPlus4E, RegWriteE, SelectorE.name(), MemWriteE, MemReadE,
            BranchE, CsrAccessE, ALUSrcE, AuipcE, WordOpE, EcallE, EbreakE, MRetE, IllegaleInstructionE, RdFE.name(), RD1FE, RD2FE,
            FPUControlE.name(), RoundModeE.name(), FPURegWriteE, MoveOperationE.name(), Rs1FE.name(), Rs2FE.name(), FPUValidE);
        endfunction: convert2str

        function void post_randomize;
            PCPlus4D = PCPlus4D + 4;
        endfunction: post_randomize

        // Compare one field and report it; returns 1 on a match
        function bit chk(string name, logic [63:0] act, logic [63:0] exp);
            if(act !== exp)
            begin
                `uvm_info({name, " Mismatch"}, $sformatf("Expected: %0h Actual: %0h", exp, act), UVM_LOW)
                return 1'b0;
            end
            return 1'b1;
        endfunction:chk

        // this = actual, rhs = expected (carries the compare masks)
        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            decode_item e;
            bit ok;
            if(!$cast(e, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a decode_item")
                return 1'b0;
            end
            ok = super.do_compare(rhs, comparer);
            // Combinational decode outputs and the always-meaningful fields
            ok &= chk("Rs1D", Rs1D, e.Rs1D) & chk("Rs2D", Rs2D, e.Rs2D);
            ok &= chk("ValidE", ValidE, e.ValidE);
            ok &= chk("PCPlus4E", PCPlus4E, e.PCPlus4E);
            ok &= chk("IllegaleInstructionE", IllegaleInstructionE, e.IllegaleInstructionE);
            if(e.chk_all)
            begin
                // Side-effect controls must be exact for a legal instruction
                ok &= chk("RdE", RdE, e.RdE) & chk("RegWriteE", RegWriteE, e.RegWriteE);
                ok &= chk("SelectorE", SelectorE, e.SelectorE) & chk("MemWriteE", MemWriteE, e.MemWriteE);
                ok &= chk("MemReadE", MemReadE, e.MemReadE) & chk("BranchE", BranchE, e.BranchE);
                ok &= chk("JumpE", JumpE, e.JumpE) & chk("JalrE", JalrE, e.JalrE);
                ok &= chk("ALUSrcE", ALUSrcE, e.ALUSrcE) & chk("AuipcE", AuipcE, e.AuipcE);
                ok &= chk("WordOpE", WordOpE, e.WordOpE) & chk("CsrAccessE", CsrAccessE, e.CsrAccessE);
                ok &= chk("EcallE", EcallE, e.EcallE) & chk("EbreakE", EbreakE, e.EbreakE) & chk("MRetE", MRetE, e.MRetE);
                ok &= chk("FPURegWriteE", FPURegWriteE, e.FPURegWriteE) & chk("FPUValidE", FPUValidE, e.FPUValidE);
                ok &= chk("funct3E", funct3E, e.funct3E);
                if(e.chk_rs1) ok &= chk("Rs1E", Rs1E, e.Rs1E) & chk("RD1E", RD1E, e.RD1E);
                if(e.chk_rs2) ok &= chk("Rs2E", Rs2E, e.Rs2E) & chk("RD2E", RD2E, e.RD2E);
                if(e.chk_imm) ok &= chk("SignImmE", SignImmE, e.SignImmE);
                if(e.chk_tgt) ok &= chk("PCBranchE", PCBranchE, e.PCBranchE);
                if(e.chk_alu) ok &= chk("ALUControlE", ALUControlE, e.ALUControlE);
                if(e.chk_csr) ok &= chk("CsrOperationE", CsrOperationE, e.CsrOperationE) & chk("CsrIndexE", CsrIndexE, e.CsrIndexE);
                if(e.chk_fp)
                begin
                    ok &= chk("FPUControlE", FPUControlE, e.FPUControlE) & chk("MoveOperationE", MoveOperationE, e.MoveOperationE);
                    ok &= chk("RoundModeE", RoundModeE, e.RoundModeE) & chk("RdFE", RdFE, e.RdFE);
                    ok &= chk("Rs1FE", Rs1FE, e.Rs1FE) & chk("Rs2FE", Rs2FE, e.Rs2FE);
                    ok &= chk("RD1FE", RD1FE, e.RD1FE) & chk("RD2FE", RD2FE, e.RD2FE);
                end
            end
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            decode_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_copy","rhs is not a decode_item")
                return;
            end
            super.do_copy(rhs);
            copy_inputs(rhs);
            this.Rs1E                 = other.Rs1E;
            this.Rs2E                 = other.Rs2E;
            this.Rs1D                 = other.Rs1D;
            this.Rs2D                 = other.Rs2D;
            this.RdE                  = other.RdE;
            this.ValidE               = other.ValidE;
            this.JumpE                = other.JumpE;
            this.JalrE                = other.JalrE;
            this.ALUControlE          = other.ALUControlE;
            this.CsrOperationE        = other.CsrOperationE;
            this.RD1E                 = other.RD1E;
            this.RD2E                 = other.RD2E;
            this.SignImmE             = other.SignImmE;
            this.PCBranchE            = other.PCBranchE;
            this.CsrIndexE            = other.CsrIndexE;
            this.funct3E              = other.funct3E;
            this.PCPlus4E             = other.PCPlus4E;
            this.RegWriteE            = other.RegWriteE;
            this.SelectorE            = other.SelectorE;
            this.MemWriteE            = other.MemWriteE;
            this.MemReadE             = other.MemReadE;
            this.BranchE              = other.BranchE;
            this.CsrAccessE           = other.CsrAccessE;
            this.ALUSrcE              = other.ALUSrcE;
            this.AuipcE               = other.AuipcE;
            this.WordOpE              = other.WordOpE;
            this.EcallE               = other.EcallE;
            this.EbreakE              = other.EbreakE;
            this.MRetE                = other.MRetE;
            this.IllegaleInstructionE = other.IllegaleInstructionE;
            this.RdFE                 = other.RdFE;
            this.RD1FE                = other.RD1FE;
            this.RD2FE                = other.RD2FE;
            this.FPUControlE          = other.FPUControlE;
            this.RoundModeE           = other.RoundModeE;
            this.FPURegWriteE         = other.FPURegWriteE;
            this.MoveOperationE       = other.MoveOperationE;
            this.Rs1FE                = other.Rs1FE;
            this.Rs2FE                = other.Rs2FE;
            this.FPUValidE            = other.FPUValidE;
            this.chk_all              = other.chk_all;
            this.chk_rs1              = other.chk_rs1;
            this.chk_rs2              = other.chk_rs2;
            this.chk_imm              = other.chk_imm;
            this.chk_tgt              = other.chk_tgt;
            this.chk_alu              = other.chk_alu;
            this.chk_fp               = other.chk_fp;
            this.chk_csr              = other.chk_csr;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            decode_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("copy_inputs","rhs is not a decode_item")
                return;
            end
            this.rst          = other.rst;
            this.PCPlus4D     = other.PCPlus4D;
            this.InstructionD = other.InstructionD;
            this.ValidD       = other.ValidD;
            this.RdW          = other.RdW;
            this.FlushE       = other.FlushE;
            this.StallE       = other.StallE;
            this.RegWriteW    = other.RegWriteW;
            this.ResultW      = other.ResultW;
            this.RdFW         = other.RdFW;
            this.FPUOutW      = other.FPUOutW;
            this.FPURegWriteW = other.FPURegWriteW;
        endfunction:copy_inputs

    endclass: decode_item

endpackage:decode_item_pkg
