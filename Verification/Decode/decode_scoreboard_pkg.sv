package decode_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import decode_item_pkg::*;

    class decode_scoreboard extends uvm_scoreboard;

        gpr_t Rs1E;
        gpr_t Rs2E;
        gpr_t Rs1D;
        gpr_t Rs2D;
        gpr_t RdE;
        logic JumpE;
        alu_operation_t ALUControlE;
        csr_t CsrOperationE;
        logic signed [FINAL_DATA_WIDTH-1:0] RD1E;
        logic signed [FINAL_DATA_WIDTH-1:0] RD2E;
        logic signed [FINAL_DATA_WIDTH-1:0] SignImmE;
        logic [FINAL_ADDR_WIDTH-1:0] PCBranchE;
        csr_index_t CsrIndexE;
        logic [2:0] funct3E;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4E;
        logic RegWriteE ; 
        selector_t SelectorE;
        logic MemWriteE;
        logic BranchE;
        logic CsrAccessE;
        logic ALUSrcE;
        logic MRetE;
        logic EcallE;
        logic EbreakE;
        logic IllegaleInstructionE;
        fpr_t RdFE;
        logic [FINAL_DATA_WIDTH-1:0] RD1FE;
        logic [FINAL_DATA_WIDTH-1:0] RD2FE;
        fpu_operation_t FPUControlE;
        round_mode_t RoundModeE;
        logic FPURegWriteE;
        move_operation_t MoveOperationE;
        fpr_t Rs1FE;
        fpr_t Rs2FE;
        fpr_t Rs1FD;
        fpr_t Rs2FD;
        logic FPUValidE;

        logic signed [FINAL_DATA_WIDTH-1:0] RegFile [32];
        logic [FINAL_DATA_WIDTH-1:0] FPURegFile [32];

        int success,fail;

        //Register the class to the factory
        `uvm_component_utils(decode_scoreboard)

        //Override the constructor function
        function new (string name = "decode_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        decode_item sc_item;
        uvm_analysis_imp #(decode_item , decode_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ref_model ();
            Rs1D = gpr_t'(sc_item.InstructionD[19:15]);
            Rs2D = gpr_t'(sc_item.InstructionD[24:20]);
            Rs1FD = fpr_t'(sc_item.InstructionD[19:15]);
            Rs2FD = fpr_t'(sc_item.InstructionD[24:20]);
            if(!sc_item.rst)
            begin
                foreach(RegFile[i])
                begin
                    RegFile[i] = 'b0;
                end
                foreach(FPURegFile[i])
                begin
                    FPURegFile[i] = 'b0;
                end
            end
            else
            begin
                if(sc_item.RegWriteW)
                begin
                    if(sc_item.MoveOperationW == FPUToReg)
                        RegFile[int'(sc_item.RdW)] = sc_item.FPUOutW;
                    else
                        RegFile[int'(sc_item.RdW)] = sc_item.ResultW;
                end
                if(sc_item.FPURegWriteW)
                    FPURegFile[int'(sc_item.RdFW)] = sc_item.FPUOutW;
            end
            
            if(!sc_item.rst)
            begin
                Rs1E = zero;
                Rs2E = zero;
                RdE = zero;
                ALUControlE = ADD;
                RD1E = 'b0;
                RD2E = 'b0;
                SignImmE = 'b0;
                PCBranchE = 'b0;
                funct3E = 'b0;
                RegWriteE = 'b0;
                MemWriteE = 'b0;
                BranchE = 'b0;
                ALUSrcE = 'b0;
                JumpE = 'b0;
                SelectorE = ALUToReg;
                CsrAccessE = 'b0;
                CsrIndexE = mstatus;
                CsrOperationE = csrrw;
                PCPlus4E = 'b0;
                EcallE = 'b0;
                EbreakE = 'b0;
                MRetE = 'b0;
                IllegaleInstructionE = 'b0;
                RdFE = f0;
                RD1FE = 'b0;
                RD2FE = 'b0;
                FPUControlE = NOOPERATION;
                RoundModeE = RNE;
                FPURegWriteE = 1'b0;
                MoveOperationE = FPUToFPU;
                Rs1FE = f0;
                Rs2FE = f0;
                FPUValidE = 1'b0;
            end
            else if(sc_item.FlushE)
            begin
                Rs1E = zero;
                Rs2E = zero;
                RdE = zero;
                ALUControlE = ADD;
                RD1E = 'b0;
                RD2E = 'b0;
                SignImmE = 'b0;
                PCBranchE = 'b0;
                funct3E = 'b0;
                RegWriteE = 'b0;
                SelectorE = ALUToReg;
                MemWriteE = 'b0;
                BranchE = 'b0;
                ALUSrcE = 'b0;
                JumpE = 'b0;
                CsrAccessE = 'b0;
                CsrOperationE = csrrw; // Reset CSR operation
                CsrIndexE = mstatus; // Reset CSR index
                PCPlus4E = 'b0;
                EcallE = 'b0;
                EbreakE = 'b0;
                MRetE = 'b0;
                IllegaleInstructionE = 'b0;
                RdFE = f0;
                RD1FE = 'b0;
                RD2FE = 'b0;
                FPUControlE = NOOPERATION;
                RoundModeE = RNE;
                FPURegWriteE = 1'b0;
                MoveOperationE = FPUToFPU;
                Rs1FE = f0;
                Rs2FE = f0;
                FPUValidE = 1'b0;
            end
            else
            begin
                Rs1E = gpr_t'(sc_item.InstructionD[19:15]);
                Rs2E = gpr_t'(sc_item.InstructionD[24:20]);
                RdE = gpr_t'(sc_item.InstructionD[11:7]);
                Rs1FE = fpr_t'(sc_item.InstructionD[19:15]);
                Rs2FE = fpr_t'(sc_item.InstructionD[24:20]);
                RdFE = fpr_t'(sc_item.InstructionD[11:7]);
                CsrOperationE = csr_t'(sc_item.InstructionD[14:12]);
                RoundModeE = round_mode_t'(sc_item.InstructionD[14:12]);
                CsrIndexE = csr_index_t'(sc_item.InstructionD[31:20]);
                RD1E = RegFile[int'(Rs1E)];
                RD2E = RegFile[int'(Rs2E)];
                RD1FE = FPURegFile[int'(Rs1FE)];
                RD2FE = FPURegFile[int'(Rs2FE)];
                SignImmE = 'b0;
                funct3E = sc_item.InstructionD[14:12];
                RegWriteE = 'b0;
                SelectorE = ALUToReg;
                MemWriteE = 'b0;
                BranchE = 'b0;
                ALUSrcE = 'b0;
                CsrAccessE = 'b0;
                ALUControlE = ADD;
                JumpE = 'b0;
                PCPlus4E = sc_item.PCPlus4D;
                EcallE = 'b0;
                EbreakE = 'b0;
                MRetE = 'b0;
                IllegaleInstructionE = 'b1;
                FPUControlE = NOOPERATION;
                MoveOperationE = FPUToFPU;
                FPURegWriteE = 1'b0;
                FPUValidE = 1'b0;
                case(opcode_t'(sc_item.InstructionD[6:0]))
                    R_TYPE:
                    begin:RType
                        RegWriteE = 1'b1;
                        IllegaleInstructionE = 'b0;
                        if(!sc_item.InstructionD[FINAL_DATA_WIDTH-1:25])
                        begin
                            case(sc_item.InstructionD[14:12])
                                3'b000: ALUControlE = ADD;
                                3'b001: ALUControlE = SLL;
                                3'b010: ALUControlE = SLT;
                                3'b011: ALUControlE = SLTU;
                                3'b100: ALUControlE = XOR;
                                3'b101: ALUControlE = SRL;
                                3'b110: ALUControlE = OR;
                                3'b111: ALUControlE = AND;
                            endcase
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_0000)
                        begin
                            case(sc_item.InstructionD[14:12])
                                3'b101: ALUControlE = SRA;
                                3'b000: ALUControlE = SUB;
                            endcase
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0001) // MUL instructions
                        begin
                            case(sc_item.InstructionD[14:12])
                                3'b000: ALUControlE = MUL;
                                3'b001: ALUControlE = MULH;
                                3'b010: ALUControlE = MULHSU;
                                3'b011: ALUControlE = MULHU;
                                3'b100: ALUControlE = DIV;
                                3'b101: ALUControlE = DIVU;
                                3'b110: ALUControlE = REM;
                                3'b111: ALUControlE = REMU;
                            endcase
                        end
                        
                    end:RType
                    LOAD:
                    begin:Load
                        RegWriteE = 1'b1;
                        SelectorE = MemToReg;
                        IllegaleInstructionE = 'b0;
                        ALUSrcE = 1'b1;
                        ALUControlE = ADD;
                        SignImmE = {{20{sc_item.InstructionD[FINAL_DATA_WIDTH-1]}},sc_item.InstructionD[FINAL_DATA_WIDTH-1:20]};
                    end:Load
                    S_TYPE:
                    begin:Store
                        MemWriteE = 1'b1;
                        ALUControlE = ADD;
                        IllegaleInstructionE = 'b0;
                        ALUSrcE = 1'b1;
                        SignImmE = {{20{sc_item.InstructionD[FINAL_DATA_WIDTH-1]}},sc_item.InstructionD[FINAL_DATA_WIDTH-1:25],sc_item.InstructionD[11:7]};
                    end:Store
                    B_TYPE:
                    begin:Branch
                        BranchE = 1'b1;
                        IllegaleInstructionE = 'b0;
                        case(branch_t'(sc_item.InstructionD[14:12]))
                            BEQ: ALUControlE = SUB;
                            BNE: ALUControlE = SUB;
                            BLT: ALUControlE = SUB;
                            BGE: ALUControlE = SUB;
                            BLTU: ALUControlE = SLTU;
                            BGEU: ALUControlE = SLTU;
                        endcase
                        SignImmE = {{20{sc_item.InstructionD[FINAL_DATA_WIDTH-1]}},sc_item.InstructionD[FINAL_DATA_WIDTH-1],sc_item.InstructionD[7],sc_item.InstructionD[FINAL_DATA_WIDTH-2:25],sc_item.InstructionD[11:8]};
                    end:Branch
                    I_TYPE:
                    begin:Immediate
                        RegWriteE = 1'b1;
                        ALUSrcE = 1'b1;
                        IllegaleInstructionE = 'b0;
                        case(sc_item.InstructionD[14:12])
                            3'b000: ALUControlE = ADD;
                            3'b010: ALUControlE = SLT;
                            3'b011: ALUControlE = SLTU;
                            3'b100: ALUControlE = XOR;
                            3'b110: ALUControlE = OR;
                            3'b111: ALUControlE = AND;
                        endcase
                        SignImmE = {{20{sc_item.InstructionD[FINAL_DATA_WIDTH-1]}},sc_item.InstructionD[FINAL_DATA_WIDTH-1:20]};
                    end:Immediate
                    JAL:
                    begin:JumpAndLink
                        RegWriteE = 1'b1;
                        ALUSrcE = 1'b1;
                        JumpE = 1'b1;
                        IllegaleInstructionE = 'b0;
                        ALUControlE = ADD;
                        SelectorE = PCToReg;
                        SignImmE = {{12{sc_item.InstructionD[FINAL_DATA_WIDTH-1]}},sc_item.InstructionD[19:12],sc_item.InstructionD[20],sc_item.InstructionD[30:21],1'b0};
                    end:JumpAndLink
                    JALR:
                    begin:JumpAndLinkRegister
                        RegWriteE = 1'b1;
                        ALUSrcE = 1'b1;
                        JumpE = 1'b1;
                        IllegaleInstructionE = 'b0;
                        SelectorE = PCToReg;
                        ALUControlE = ADD;
                        SignImmE = {{20{sc_item.InstructionD[FINAL_DATA_WIDTH-1]}},sc_item.InstructionD[FINAL_DATA_WIDTH-1:20]};
                    end:JumpAndLinkRegister
                    CSR:
                    begin:ControlAndStatus
                        IllegaleInstructionE = 'b0;
                        if(csr_t'(sc_item.InstructionD[14:12]) == system)
                        begin
                        if(sc_item.InstructionD[31:20] == 12'b0000_0000_0000) //ECALL
                            EcallE = 'b1;
                        else if(sc_item.InstructionD[31:20] == 12'b0000_0000_0001) //EBREAK
                            EbreakE = 'b1;
                        else if(sc_item.InstructionD[31:20] == 12'b0011_0000_0010) //MRET
                            MRetE = 'b1;
                        end
                        else
                        begin
                            CsrAccessE = 1'b1;
                            RegWriteE = 1'b1;
                            SelectorE = CSRToReg;
                            ALUControlE = ADD;
                        end
                    end:ControlAndStatus
                    FLOATING_PT:
                    begin:FloatingPoint
                        if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0000)
                        begin
                            FPURegWriteE = 1'b1;
                            IllegaleInstructionE = 'b0;
                            FPUControlE = FADD_S;
                            MoveOperationE = FPUToFPU;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0100)
                        begin
                            FPURegWriteE = 1'b1;
                            IllegaleInstructionE = 'b0;
                            FPUControlE = FSUB_S;
                            MoveOperationE = FPUToFPU;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_1000)
                        begin
                            FPURegWriteE = 1'b1;
                            IllegaleInstructionE = 'b0;
                            FPUControlE = FMUL_S;
                            MoveOperationE = FPUToFPU;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_1100)
                        begin
                            FPURegWriteE = 1'b1;
                            IllegaleInstructionE = 'b0;
                            FPUControlE = FDIV_S;
                            MoveOperationE = FPUToFPU;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_1100)
                        begin
                            if(Rs2FD == f0)
                            begin
                                FPURegWriteE = 1'b1;
                                IllegaleInstructionE = 'b0;
                                FPUControlE = FSQRT_S;
                                MoveOperationE = FPUToFPU;
                            end
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0000)
                        begin
                            FPURegWriteE = 1'b1;
                            MoveOperationE = FPUToFPU;
                            IllegaleInstructionE = 'b0;
                            if(sc_item.InstructionD[14:12] == 3'b000)
                                FPUControlE = FSGNJ_S;
                            else if(sc_item.InstructionD[14:12] == 3'b001)
                                FPUControlE = FSGNJN_S;
                            else if(sc_item.InstructionD[14:12] == 3'b010)
                                FPUControlE = FSGNJX_S;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0100)
                        begin
                            FPURegWriteE = 1'b1;
                            MoveOperationE = FPUToFPU;
                            IllegaleInstructionE = 'b0;
                            if(sc_item.InstructionD[14:12] == 3'b000)
                                FPUControlE = FMIN_S;
                            else if(sc_item.InstructionD[14:12] == 3'b001)
                                FPUControlE = FMAX_S;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_0000)
                        begin
                            RegWriteE = 1'b1;
                            MoveOperationE = FPUToReg;
                            IllegaleInstructionE = 'b0;
                            if(Rs2FD == f0)
                                FPUControlE = FCVT_W_S;
                            else if(Rs2FD == f1)
                                FPUControlE = FCVT_WU_S;
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_0000)
                        begin
                            if(Rs2FD == f0)
                            begin
                                if(sc_item.InstructionD[14:12] == 3'b000)
                                begin
                                    FPUControlE = FMV_X_S;
                                    MoveOperationE = FPUToReg;
                                    RegWriteE = 1'b1;
                                    IllegaleInstructionE = 'b0;
                                end
                                else if(sc_item.InstructionD[14:12] == 3'b001)
                                begin
                                    FPUControlE = FCLASS_S;
                                    MoveOperationE = FPUToFPU;
                                    FPURegWriteE = 1'b1;
                                    IllegaleInstructionE = 'b0;
                                end
                            end
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b101_0000)
                        begin
                            if(sc_item.InstructionD[14:12] == 3'b000)
                            begin
                                FPUControlE = FLE_S;
                                FPURegWriteE = 1'b1;
                                MoveOperationE = FPUToFPU;
                                IllegaleInstructionE = 'b0;
                            end
                            else if(sc_item.InstructionD[14:12] == 3'b001)
                            begin
                                FPUControlE = FLT_S;
                                FPURegWriteE = 1'b1;
                                MoveOperationE = FPUToFPU;
                                IllegaleInstructionE = 'b0;
                            end
                            else if(sc_item.InstructionD[14:12] == 3'b010)
                            begin
                                FPUControlE = FEQ_S;
                                FPURegWriteE = 1'b1;
                                MoveOperationE = FPUToFPU;
                                IllegaleInstructionE = 'b0;
                            end
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_1000)
                        begin
                            if(Rs2FD == f0)
                            begin
                                FPURegWriteE = 1'b1;
                                MoveOperationE = RegToFPU;
                                IllegaleInstructionE = 'b0;
                                FPUControlE = FCVT_S_W;
                            end
                            else if(Rs2FD == f1)
                            begin
                                FPURegWriteE = 1'b1;
                                MoveOperationE = RegToFPU;
                                IllegaleInstructionE = 'b0;
                                FPUControlE = FCVT_S_WU;
                            end
                        end
                        else if(sc_item.InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_1000)
                        begin
                            if(Rs2FD == f0 && sc_item.InstructionD[14:12] == 3'b000)
                            begin
                                FPUControlE = FMV_S_X;
                                MoveOperationE = RegToFPU;
                                FPURegWriteE = 1'b1;
                                IllegaleInstructionE = 'b0;
                            end
                        end
                    end:FloatingPoint
                endcase
                FPUValidE = (FPUControlE != NOOPERATION);
                PCBranchE = sc_item.PCPlus4D + (SignImmE * 4);
            end
        endfunction:ref_model

        function void check_output ();
            ref_model();
            if
            (
                sc_item.Rs1E != Rs1E || 
                sc_item.Rs2E != Rs2E || 
                sc_item.RdE != sc_item.RdE || 
                sc_item.ALUControlE != ALUControlE || 
                sc_item.RD1E != RD1E || 
                sc_item.RD2E != RD2E || 
                sc_item.SignImmE != SignImmE || 
                sc_item.PCBranchE != PCBranchE || 
                sc_item.funct3E != funct3E || 
                sc_item.RegWriteE != RegWriteE || 
                sc_item.SelectorE != SelectorE || 
                sc_item.MemWriteE != MemWriteE || 
                sc_item.BranchE != BranchE || 
                sc_item.ALUSrcE != ALUSrcE || 
                sc_item.Rs1D != Rs1D || 
                sc_item.Rs2D != Rs2D || 
                sc_item.JumpE != JumpE || 
                CsrAccessE != sc_item.CsrAccessE || 
                CsrIndexE != sc_item.CsrIndexE || 
                CsrOperationE != sc_item.CsrOperationE ||
                PCPlus4E != sc_item.PCPlus4E ||
                EbreakE != sc_item.EbreakE ||
                MRetE != sc_item.MRetE ||
                IllegaleInstructionE != sc_item.IllegaleInstructionE ||
                EcallE != sc_item.EcallE ||
                FPUValidE != sc_item.FPUValidE
            )
            begin
                $display("//////////////////////Error occured in the Decode scoreboard//////////////////////");
                `uvm_info("SCB",sc_item.convert2str,UVM_MEDIUM)
                if(sc_item.JumpE != JumpE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output JumpE = %0h -- JumpE = %0h",sc_item.JumpE,JumpE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.Rs1E != Rs1E)
                begin
                    `uvm_info("SCB",$sformatf("Actual output Rs1E = %0h -- Rs1E = %0h",sc_item.Rs1E,Rs1E),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.Rs2E != Rs2E)
                begin
                    `uvm_info("SCB",$sformatf("Actual output Rs2E = %0h -- Rs2E = %0h",sc_item.Rs2E,Rs2E),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RdE != sc_item.RdE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RdE = %0h -- RdE = %0h",sc_item.RdE,sc_item.RdE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.ALUControlE != ALUControlE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output ALUControlE = %s -- ALUControlE = %s",sc_item.ALUControlE.name,ALUControlE.name),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RD1E != RD1E)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RD1E = %0h -- RD1E = %0h",sc_item.RD1E,RD1E),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RD2E != RD2E)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RD2E = %0h -- RD2E = %0h",sc_item.RD2E,RD2E),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.SignImmE != SignImmE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output SignImmE = %0h -- SignImmE = %0h",sc_item.SignImmE,SignImmE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.PCBranchE != PCBranchE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output PCBranchE = %0h -- PCBranchE = %0h",sc_item.PCBranchE,PCBranchE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.funct3E != funct3E)
                begin    
                    `uvm_info("SCB",$sformatf("Actual output funct3E = %0h -- funct3E = %0h",sc_item.funct3E,funct3E),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RegWriteE != RegWriteE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RegWriteE = %0h -- RegWriteE = %0h",sc_item.RegWriteE,RegWriteE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.SelectorE != SelectorE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output SelectorE = %s -- SelectorE = %s",sc_item.SelectorE.name,SelectorE.name),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.MemWriteE != MemWriteE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output MemWriteE = %0h -- MemWriteE = %0h",sc_item.MemWriteE,MemWriteE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.BranchE != BranchE)
                begin    
                    `uvm_info("SCB",$sformatf("Actual output BranchE = %0h -- BranchE = %0h",sc_item.BranchE,BranchE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.ALUSrcE != ALUSrcE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output ALUSrcE = %0h -- ALUSrcE = %0h",sc_item.ALUSrcE,ALUSrcE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.Rs1D != Rs1D)
                begin
                    `uvm_info("SCB",$sformatf("Actual output Rs1D = %0h -- Rs1D = %0h",sc_item.Rs1D,Rs1D),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.Rs2D != Rs2D)
                begin
                    `uvm_info("SCB",$sformatf("Actual output Rs2D = %0h -- Rs2D = %0h",sc_item.Rs2D,Rs2D),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.CsrAccessE != CsrAccessE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output CsrAccessE = %s -- CsrAccessE = %s",sc_item.CsrAccessE,CsrAccessE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.CsrIndexE != CsrIndexE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output CsrIndexE = %s -- CsrIndexE = %s",sc_item.CsrIndexE.name,CsrIndexE.name),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.CsrOperationE != CsrOperationE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output CsrOperationE = %s -- CsrOperationE = %s",sc_item.CsrOperationE.name,CsrOperationE.name),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.PCPlus4E != PCPlus4E)
                begin
                    `uvm_info("SCB",$sformatf("Actual output PCPlus4E = %0h -- PCPlus4E = %0h",sc_item.PCPlus4E,PCPlus4E),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.EbreakE != EbreakE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output EbreakE = %0h -- EbreakE = %0h",sc_item.EbreakE,EbreakE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.MRetE != MRetE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output MRetE = %0h -- MRetE = %0h",sc_item.MRetE,MRetE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.IllegaleInstructionE != IllegaleInstructionE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output IllegaleInstructionE = %0h -- IllegaleInstructionE = %0h",sc_item.IllegaleInstructionE,IllegaleInstructionE),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.EcallE != EcallE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output EcallE = %0h -- EcallE = %0h",sc_item.EcallE,EcallE),UVM_MEDIUM)
                    fail++;
                end
                if(RdFE != sc_item.RdFE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RdFE = %s -- RdFE = %s",sc_item.RdFE.name(),RdFE.name()),UVM_MEDIUM)
                    fail++;
                end
                if(RD1FE != sc_item.RD1FE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RD1FE = %0h -- RD1FE = %0h",sc_item.RD1FE,RD1FE),UVM_MEDIUM)
                    fail++;
                end
                if(RD2FE != sc_item.RD2FE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RD2FE = %0h -- RD2FE = %0h",sc_item.RD2FE,RD2FE),UVM_MEDIUM)
                    fail++;
                end
                if(FPUControlE != sc_item.FPUControlE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output FPUControlE = %s -- FPUControlE = %s",sc_item.FPUControlE.name(),FPUControlE.name()),UVM_MEDIUM)
                    fail++;
                end
                if(RoundModeE != sc_item.RoundModeE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RoundModeE = %s -- RoundModeE = %s",sc_item.RoundModeE.name(),RoundModeE.name()),UVM_MEDIUM)
                    fail++;
                end
                if(FPURegWriteE != sc_item.FPURegWriteE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output FPURegWriteE = %0h -- FPURegWriteE = %0h",sc_item.FPURegWriteE,FPURegWriteE),UVM_MEDIUM)
                    fail++;
                end
                if(MoveOperationE != sc_item.MoveOperationE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output MoveOperationE = %s -- MoveOperationE = %s",sc_item.MoveOperationE.name(),MoveOperationE.name()),UVM_MEDIUM)
                    fail++;
                end
                if(Rs1FE != sc_item.Rs1FE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output Rs1FE = %s -- Rs1FE = %s",sc_item.Rs1FE.name(),Rs1FE.name()),UVM_MEDIUM)
                    fail++;
                end
                if(Rs2FE != sc_item.Rs2FE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output Rs2FE = %s -- Rs2FE = %s",sc_item.Rs2FE.name(),Rs2FE.name()),UVM_MEDIUM)
                    fail++;
                end
                if(FPUValidE != sc_item.FPUValidE)
                begin
                    `uvm_info("SCB",$sformatf("Actual output FPUValidE = %0h -- FPUValidE = %0h",sc_item.FPUValidE,FPUValidE),UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (decode_item item);
            sc_item = item;
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","DECODE Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:decode_scoreboard

endpackage:decode_scoreboard_pkg
