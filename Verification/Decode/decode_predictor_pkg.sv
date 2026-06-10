// =============================================================================
// decode_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Decode stage.
//
// DUT decoupling:
//   - *D outputs (Rs1D, Rs2D) are combinational on InstructionD - emit
//     from the current monitored InstructionD.
//   - *E outputs (Rs1E, Rs2E, RdE, RD1E, ALUControlE, ...) are registered in
//     the ID/EX pipeline register - shadow them and use emit-before-update so
//     the expected transaction lines up with the registered DUT outputs the
//     monitor sampled this cycle.
//   - Asynchronous active-low rst forces *E to reset defaults immediately, so
//     when t.rst == 0 the shadow is flushed and reset defaults are emitted in
//     the SAME cycle (rst is the only signal allowed to "update before emit").
//   - FlushE is synchronous so the flush only affects the NEXT-cycle shadow
//     (computed at the end of write()), not the current emit.
//
// Register-file timing:
//   The integer / FP register files have sequential write and combinational
//   read.  The DUT's posedge-N latch into *E uses pre-posedge RegFile reads
//   (NBA reads RHS before NBA region settles), so the predictor must compute
//   the NEXT-cycle shadow with the CURRENT predictor RegFile state and only
//   apply the cycle's write-back AFTER that compute - matching the order the
//   DUT effectively executes at the posedge.
// =============================================================================
package decode_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import decode_item_pkg::*;

    class decode_predictor extends uvm_subscriber #(decode_item);

        `uvm_component_utils(decode_predictor)

        function new (string name = "decode_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(decode_item) exp_port;
        decode_item shadow_input, exp, exp_clone;

        // ── Sequential DUT state (registered) ────────────────────────────────
        logic signed [FINAL_DATA_WIDTH-1:0] RegFile    [32];
        logic [FINAL_DATA_WIDTH-1:0]        FPURegFile [32];

        // ── ID/EX pipeline-register shadows (one per registered *E output) ───
        gpr_t                                  q_Rs1E, q_Rs2E, q_RdE;
        alu_operation_t                        q_ALUControlE;
        csr_t                                  q_CsrOperationE;
        logic signed [FINAL_DATA_WIDTH-1:0]    q_RD1E, q_RD2E, q_SignImmE;
        logic [FINAL_ADDR_WIDTH-1:0]           q_PCBranchE, q_PCPlus4E;
        csr_index_t                            q_CsrIndexE;
        logic [2:0]                            q_funct3E;
        logic                                  q_RegWriteE, q_MemWriteE, q_BranchE;
        logic                                  q_ALUSrcE, q_JumpE, q_CsrAccessE;
        selector_t                             q_SelectorE;
        logic                                  q_EcallE, q_EbreakE, q_MRetE;
        logic                                  q_IllegaleInstructionE;
        fpr_t                                  q_RdFE, q_Rs1FE, q_Rs2FE;
        logic [FINAL_DATA_WIDTH-1:0]           q_RD1FE, q_RD2FE;
        fpu_operation_t                        q_FPUControlE;
        round_mode_t                           q_RoundModeE;
        logic                                  q_FPURegWriteE, q_FPUValidE;
        move_operation_t                       q_MoveOperationE;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = decode_item::type_id::create("exp");
            reset_regfiles();
            reset_shadow();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_regfiles();
            reset_shadow();
        endtask:reset_phase

        // ── State resets (mirror DUT reset block) ────────────────────────────
        function void reset_regfiles();
            foreach(RegFile[i])    RegFile[i]    = '0;
            foreach(FPURegFile[i]) FPURegFile[i] = '0;
        endfunction:reset_regfiles

        function void reset_shadow();
            q_Rs1E = zero; q_Rs2E = zero; q_RdE = zero;
            q_ALUControlE          = ADD;
            q_RD1E                 = '0;
            q_RD2E                 = '0;
            q_SignImmE             = '0;
            q_PCBranchE            = '0;
            q_funct3E              = '0;
            q_RegWriteE            = 1'b0;
            q_SelectorE            = ALUToReg;
            q_MemWriteE            = 1'b0;
            q_BranchE              = 1'b0;
            q_ALUSrcE              = 1'b0;
            q_JumpE                = 1'b0;
            q_CsrOperationE        = csrrw;
            q_CsrAccessE           = 1'b0;
            q_CsrIndexE            = mstatus;
            q_PCPlus4E             = '0;
            q_EcallE               = 1'b0;
            q_EbreakE              = 1'b0;
            q_MRetE                = 1'b0;
            q_IllegaleInstructionE = 1'b0;
            q_RdFE                 = f0;
            q_Rs1FE                = f0;
            q_Rs2FE                = f0;
            q_RD1FE                = '0;
            q_RD2FE                = '0;
            q_FPUControlE          = NOOPERATION;
            q_RoundModeE           = RNE;
            q_FPURegWriteE         = 1'b0;
            q_MoveOperationE       = FPUToFPU;
            q_FPUValidE            = 1'b0;
        endfunction:reset_shadow

        // ── Helpers ──────────────────────────────────────────────────────────
        function void apply_wb(decode_item t);
            if(t.RegWriteW && (t.RdW != zero))
            begin
                if(t.MoveOperationW == FPUToReg)
                    RegFile[int'(t.RdW)] = t.FPUOutW;
                else
                    RegFile[int'(t.RdW)] = t.ResultW;
            end
            if(t.FPURegWriteW)
                FPURegFile[int'(t.RdFW)] = t.FPUOutW;
            RegFile[0] = '0;
        endfunction:apply_wb

        function void emit_shadow(decode_item exp);
            exp.Rs1E                 = q_Rs1E;
            exp.Rs2E                 = q_Rs2E;
            exp.RdE                  = q_RdE;
            exp.ALUControlE          = q_ALUControlE;
            exp.RD1E                 = q_RD1E;
            exp.RD2E                 = q_RD2E;
            exp.SignImmE             = q_SignImmE;
            exp.PCBranchE            = q_PCBranchE;
            exp.funct3E              = q_funct3E;
            exp.RegWriteE            = q_RegWriteE;
            exp.SelectorE            = q_SelectorE;
            exp.MemWriteE            = q_MemWriteE;
            exp.BranchE              = q_BranchE;
            exp.ALUSrcE              = q_ALUSrcE;
            exp.JumpE                = q_JumpE;
            exp.CsrOperationE        = q_CsrOperationE;
            exp.CsrAccessE           = q_CsrAccessE;
            exp.CsrIndexE            = q_CsrIndexE;
            exp.PCPlus4E             = q_PCPlus4E;
            exp.MRetE                = q_MRetE;
            exp.EcallE               = q_EcallE;
            exp.EbreakE              = q_EbreakE;
            exp.IllegaleInstructionE = q_IllegaleInstructionE;
            exp.RdFE                 = q_RdFE;
            exp.RD1FE                = q_RD1FE;
            exp.RD2FE                = q_RD2FE;
            exp.FPUControlE          = q_FPUControlE;
            exp.RoundModeE           = q_RoundModeE;
            exp.MoveOperationE       = q_MoveOperationE;
            exp.FPURegWriteE         = q_FPURegWriteE;
            exp.Rs1FE                = q_Rs1FE;
            exp.Rs2FE                = q_Rs2FE;
            exp.FPUValidE            = q_FPUValidE;
        endfunction:emit_shadow

        // Compute the next-cycle *E values from the current InstructionD.
        // Mirrors the combinational control path in decode_stage.sv and reads
        // RegFile / FPURegFile BEFORE this cycle's write-back so the shadow
        // captures the values DUT will latch at the next posedge.
        function void compute_next(decode_item t);
            fpr_t Rs2FD_loc;
            Rs2FD_loc = fpr_t'(t.InstructionD[24:20]);

            q_Rs1E          = gpr_t'(t.InstructionD[19:15]);
            q_Rs2E          = gpr_t'(t.InstructionD[24:20]);
            q_RdE           = gpr_t'(t.InstructionD[11:7]);
            q_Rs1FE         = fpr_t'(t.InstructionD[19:15]);
            q_Rs2FE         = Rs2FD_loc;
            q_RdFE          = fpr_t'(t.InstructionD[11:7]);
            q_CsrOperationE = csr_t'(t.InstructionD[14:12]);
            q_RoundModeE    = round_mode_t'(t.InstructionD[14:12]);
            q_CsrIndexE     = csr_index_t'(t.InstructionD[31:20]);
            q_RD1E          = RegFile[int'(q_Rs1E)];
            q_RD2E          = RegFile[int'(q_Rs2E)];
            q_RD1FE         = FPURegFile[int'(q_Rs1FE)];
            q_RD2FE         = FPURegFile[int'(q_Rs2FE)];
            q_SignImmE      = '0;
            q_funct3E       = t.InstructionD[14:12];
            q_RegWriteE     = 1'b0;
            q_SelectorE     = ALUToReg;
            q_MemWriteE     = 1'b0;
            q_BranchE       = 1'b0;
            q_ALUSrcE       = 1'b0;
            q_CsrAccessE    = 1'b0;
            q_ALUControlE   = ADD;
            q_JumpE         = 1'b0;
            q_PCPlus4E      = t.PCPlus4D;
            q_EcallE        = 1'b0;
            q_EbreakE       = 1'b0;
            q_MRetE         = 1'b0;
            q_IllegaleInstructionE = 1'b1;
            q_FPUControlE   = NOOPERATION;
            q_MoveOperationE = FPUToFPU;
            q_FPURegWriteE  = 1'b0;
            q_FPUValidE     = 1'b0;

            case(opcode_t'(t.InstructionD[6:0]))
                R_TYPE: begin
                    q_RegWriteE            = 1'b1;
                    q_IllegaleInstructionE = 1'b0;
                    if(!t.InstructionD[FINAL_DATA_WIDTH-1:25]) begin
                        case(t.InstructionD[14:12])
                            3'b000: q_ALUControlE = ADD;
                            3'b001: q_ALUControlE = SLL;
                            3'b010: q_ALUControlE = SLT;
                            3'b011: q_ALUControlE = SLTU;
                            3'b100: q_ALUControlE = XOR;
                            3'b101: q_ALUControlE = SRL;
                            3'b110: q_ALUControlE = OR;
                            3'b111: q_ALUControlE = AND;
                        endcase
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_0000) begin
                        case(t.InstructionD[14:12])
                            3'b101: q_ALUControlE = SRA;
                            3'b000: q_ALUControlE = SUB;
                        endcase
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0001) begin
                        case(t.InstructionD[14:12])
                            3'b000: q_ALUControlE = MUL;
                            3'b001: q_ALUControlE = MULH;
                            3'b010: q_ALUControlE = MULHSU;
                            3'b011: q_ALUControlE = MULHU;
                            3'b100: q_ALUControlE = DIV;
                            3'b101: q_ALUControlE = DIVU;
                            3'b110: q_ALUControlE = REM;
                            3'b111: q_ALUControlE = REMU;
                        endcase
                    end
                end
                LOAD: begin
                    q_RegWriteE            = 1'b1;
                    q_SelectorE            = MemToReg;
                    q_IllegaleInstructionE = 1'b0;
                    q_ALUSrcE              = 1'b1;
                    q_ALUControlE          = ADD;
                    q_SignImmE = {{20{t.InstructionD[FINAL_DATA_WIDTH-1]}},
                                  t.InstructionD[FINAL_DATA_WIDTH-1:20]};
                end
                S_TYPE: begin
                    q_MemWriteE            = 1'b1;
                    q_ALUControlE          = ADD;
                    q_IllegaleInstructionE = 1'b0;
                    q_ALUSrcE              = 1'b1;
                    q_SignImmE = {{20{t.InstructionD[FINAL_DATA_WIDTH-1]}},
                                  t.InstructionD[FINAL_DATA_WIDTH-1:25],
                                  t.InstructionD[11:7]};
                end
                B_TYPE: begin
                    q_BranchE              = 1'b1;
                    q_IllegaleInstructionE = 1'b0;
                    case(branch_t'(t.InstructionD[14:12]))
                        BEQ:  q_ALUControlE = SUB;
                        BNE:  q_ALUControlE = SUB;
                        BLT:  q_ALUControlE = SUB;
                        BGE:  q_ALUControlE = SUB;
                        BLTU: q_ALUControlE = SLTU;
                        BGEU: q_ALUControlE = SLTU;
                    endcase
                    q_SignImmE = {{20{t.InstructionD[FINAL_DATA_WIDTH-1]}},
                                  t.InstructionD[FINAL_DATA_WIDTH-1],
                                  t.InstructionD[7],
                                  t.InstructionD[FINAL_DATA_WIDTH-2:25],
                                  t.InstructionD[11:8]};
                end
                I_TYPE: begin
                    q_RegWriteE            = 1'b1;
                    q_ALUSrcE              = 1'b1;
                    q_IllegaleInstructionE = 1'b0;
                    case(t.InstructionD[14:12])
                        3'b000: q_ALUControlE = ADD;
                        3'b010: q_ALUControlE = SLT;
                        3'b011: q_ALUControlE = SLTU;
                        3'b100: q_ALUControlE = XOR;
                        3'b110: q_ALUControlE = OR;
                        3'b111: q_ALUControlE = AND;
                    endcase
                    q_SignImmE = {{20{t.InstructionD[FINAL_DATA_WIDTH-1]}},
                                  t.InstructionD[FINAL_DATA_WIDTH-1:20]};
                end
                JAL: begin
                    q_RegWriteE            = 1'b1;
                    q_ALUSrcE              = 1'b1;
                    q_JumpE                = 1'b1;
                    q_IllegaleInstructionE = 1'b0;
                    q_ALUControlE          = ADD;
                    q_SelectorE            = PCToReg;
                    q_SignImmE = {{12{t.InstructionD[FINAL_DATA_WIDTH-1]}},
                                  t.InstructionD[19:12],
                                  t.InstructionD[20],
                                  t.InstructionD[30:21], 1'b0};
                end
                JALR: begin
                    q_RegWriteE            = 1'b1;
                    q_ALUSrcE              = 1'b1;
                    q_JumpE                = 1'b1;
                    q_IllegaleInstructionE = 1'b0;
                    q_SelectorE            = PCToReg;
                    q_ALUControlE          = ADD;
                    q_SignImmE = {{20{t.InstructionD[FINAL_DATA_WIDTH-1]}},
                                  t.InstructionD[FINAL_DATA_WIDTH-1:20]};
                end
                CSR: begin
                    q_IllegaleInstructionE = 1'b0;
                    if(csr_t'(t.InstructionD[14:12]) == system) begin
                        if(t.InstructionD[31:20] == 12'b0000_0000_0000)      q_EcallE  = 1'b1;
                        else if(t.InstructionD[31:20] == 12'b0000_0000_0001) q_EbreakE = 1'b1;
                        else if(t.InstructionD[31:20] == 12'b0011_0000_0010) q_MRetE   = 1'b1;
                    end
                    else begin
                        q_CsrAccessE  = 1'b1;
                        q_RegWriteE   = 1'b1;
                        q_SelectorE   = CSRToReg;
                        q_ALUControlE = ADD;
                    end
                end
                FLOATING_PT: begin
                    if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0000) begin
                        q_FPURegWriteE         = 1'b1;
                        q_IllegaleInstructionE = 1'b0;
                        q_FPUControlE          = FADD_S;
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0100) begin
                        q_FPURegWriteE         = 1'b1;
                        q_IllegaleInstructionE = 1'b0;
                        q_FPUControlE          = FSUB_S;
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_1000) begin
                        q_FPURegWriteE         = 1'b1;
                        q_IllegaleInstructionE = 1'b0;
                        q_FPUControlE          = FMUL_S;
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_1100) begin
                        q_FPURegWriteE         = 1'b1;
                        q_IllegaleInstructionE = 1'b0;
                        q_FPUControlE          = FDIV_S;
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_1100) begin
                        if(Rs2FD_loc == f0) begin
                            q_FPURegWriteE         = 1'b1;
                            q_IllegaleInstructionE = 1'b0;
                            q_FPUControlE          = FSQRT_S;
                        end
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0000) begin
                        q_IllegaleInstructionE = 1'b0;
                        if(t.InstructionD[14:12] == 3'b000)      
                        begin
                            q_FPUControlE = FSGNJ_S;
                            q_FPURegWriteE         = 1'b1;
                        end
                        else if(t.InstructionD[14:12] == 3'b001)
                        begin 
                            q_FPUControlE = FSGNJN_S;
                            q_FPURegWriteE         = 1'b1;
                        end
                        else if(t.InstructionD[14:12] == 3'b010) 
                        begin
                            q_FPUControlE = FSGNJX_S;
                            q_FPURegWriteE         = 1'b1;
                        end
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0100) begin
                        q_IllegaleInstructionE = 1'b0;
                        if(t.InstructionD[14:12] == 3'b000)      
                        begin
                            q_FPUControlE = FMIN_S;
                            q_FPURegWriteE         = 1'b1;
                        end
                        else if(t.InstructionD[14:12] == 3'b001) 
                        begin
                            q_FPUControlE = FMAX_S;
                            q_FPURegWriteE         = 1'b1;
                        end
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_0000) begin
                        q_RegWriteE            = 1'b1;
                        q_MoveOperationE       = FPUToReg;
                        q_IllegaleInstructionE = 1'b0;
                        if(Rs2FD_loc == f0)      q_FPUControlE = FCVT_W_S;
                        else if(Rs2FD_loc == f1) q_FPUControlE = FCVT_WU_S;
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_0000) begin
                        if(Rs2FD_loc == f0) 
                        begin
                            if(t.InstructionD[14:12] == 3'b000) 
                            begin
                                q_FPUControlE          = FMV_X_S;
                                q_MoveOperationE       = FPUToReg;
                                q_RegWriteE            = 1'b1;
                                q_IllegaleInstructionE = 1'b0;
                            end
                            else if(t.InstructionD[14:12] == 3'b001) 
                            begin
                                q_FPUControlE          = FCLASS_S;
                                q_FPURegWriteE         = 1'b1;
                                q_IllegaleInstructionE = 1'b0;
                            end
                        end
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b101_0000) 
                    begin
                        if(t.InstructionD[14:12] == 3'b000) 
                        begin
                            q_FPUControlE          = FLE_S;
                            q_FPURegWriteE         = 1'b1;
                            q_IllegaleInstructionE = 1'b0;
                        end
                        else if(t.InstructionD[14:12] == 3'b001) 
                        begin
                            q_FPUControlE          = FLT_S;
                            q_FPURegWriteE         = 1'b1;
                            q_IllegaleInstructionE = 1'b0;
                        end
                        else if(t.InstructionD[14:12] == 3'b010) 
                        begin
                            q_FPUControlE          = FEQ_S;
                            q_FPURegWriteE         = 1'b1;
                            q_IllegaleInstructionE = 1'b0;
                        end
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_1000) begin
                        if(Rs2FD_loc == f0) begin
                            q_FPURegWriteE         = 1'b1;
                            q_MoveOperationE       = RegToFPU;
                            q_IllegaleInstructionE = 1'b0;
                            q_FPUControlE          = FCVT_S_W;
                        end
                        else if(Rs2FD_loc == f1) begin
                            q_FPURegWriteE         = 1'b1;
                            q_MoveOperationE       = RegToFPU;
                            q_IllegaleInstructionE = 1'b0;
                            q_FPUControlE          = FCVT_S_WU;
                        end
                    end
                    else if(t.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_1000) begin
                        if(Rs2FD_loc == f0 && t.InstructionD[14:12] == 3'b000) begin
                            q_FPUControlE          = FMV_S_X;
                            q_MoveOperationE       = RegToFPU;
                            q_FPURegWriteE         = 1'b1;
                            q_IllegaleInstructionE = 1'b0;
                        end
                    end
                end
            endcase
            q_FPUValidE = (q_FPUControlE != NOOPERATION);
            q_PCBranchE = t.PCPlus4D + (q_SignImmE * 4);
        endfunction:compute_next

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (decode_item t);


            if(!t.rst)
            begin
                reset_shadow();
                reset_regfiles();
            end

            // Combinational *D outputs (always_comb on InstructionD).
            exp.Rs1D = gpr_t'(t.InstructionD[19:15]);
            exp.Rs2D = gpr_t'(t.InstructionD[24:20]);

            // Emit the shadow that matches DUT's CURRENT registered *E.
            emit_shadow(exp);
            
            if(!(shadow_input == null))
                exp.copy_inputs(shadow_input);
            
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("DECODE_PRED", "Failed to clone expected item - check for non-cloneable fields or type mismatches")
            else
                exp_port.write(exp_clone);
            

            if(t.rst)
            begin
                apply_wb(t);
                if(t.FlushE)
                    reset_shadow();
                else
                begin
                    compute_next(t);
                end
            end
            if(!$cast(shadow_input, t.clone()))
                `uvm_fatal("DECODE_PRED", "Failed to cast shadow input - check for type mismatches")
        endfunction:write

    endclass:decode_predictor

endpackage:decode_predictor_pkg
