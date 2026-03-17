package execute_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "C:/Ain_shams/RiscV/Design/csr_defs.sv"
    import shared_pkg::*;
    import execute_item_pkg::*;

    class execute_scoreboard extends uvm_scoreboard;

        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM;
        logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM;
        gpr_t RdM;
        logic PCSrcE;
        logic RegWriteM;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4M;
        selector_t SelectorM;
        logic [2:0] funct3M;
        logic [FINAL_DATA_WIDTH-1:0] CsrOutM;
        logic MemWriteM;
        logic TrapIsSet;
        logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC;
        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutE;

        logic signed [2*FINAL_DATA_WIDTH-1:0] MulOutput;
        logic signed [FINAL_DATA_WIDTH-1:0] DivOutput;
        logic signed [FINAL_DATA_WIDTH-1:0] RemOutput;


        traps_t Traps;

        logic signed [FINAL_DATA_WIDTH-1:0] IntermediateB , SrcA,SrcB;
        logic [FINAL_DATA_WIDTH-1:0] SrcBU;

        logic branch_true;
        logic [FINAL_DATA_WIDTH-1:0] CSRFile [4096];

        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM_past;
        int success,fail;
        logic [FINAL_FLP_WIDTH-1:0] FPUOutM_past;

        localparam int LOG_WIDTH = $clog2(FINAL_DATA_WIDTH);

        //Register the class to the factory
        `uvm_component_utils(execute_scoreboard)

        //Override the constructor function
        function new (string name = "execute_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        execute_item sc_item;
        uvm_analysis_imp #(execute_item , execute_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void CheckForTrap ;
            if(|sc_item.PCPlus4E[1:0])
            begin
                Traps = InstructionAddressMisalignedOrUserSoftwareInterrupt;
            end
            else if(sc_item.EbreakE | sc_item.EcallE | sc_item.IllegaleInstructionE)
            begin
                Traps = IllegalInstructionOrHypervisorSoftwareInterrupt;
            end
            else if(sc_item.SelectorE == MemToReg)
            begin
                if((load_store_t'(sc_item.funct3E) == W) && (|ALUOutE[1:0]))
                begin
                    Traps = LoadAddressMisalignedOrUserSoftwareInterrupt;
                end
                else if(((load_store_t'(sc_item.funct3E) == HW) | (load_store_t'(sc_item.funct3E) == HWU)) && (ALUOutE == 2'b11))
                begin
                    Traps = LoadAddressMisalignedOrUserSoftwareInterrupt;
                end
            end
            else if(sc_item.MemWriteE)
            begin
                if((load_store_t'(sc_item.funct3E) == W) && (|ALUOutE[1:0]))
                begin
                    Traps = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
                end
                else if((ALUOutE == 2'b11) && (load_store_t'(sc_item.funct3E) == HW))
                begin
                    Traps = StoreAddressMisalignedOrHyperVisorTimerInterrupt;
                end
            end
        endfunction:CheckForTrap 

        function void UpdateCsr(input logic [FINAL_DATA_WIDTH-1:0] X);
            if(sc_item.CsrIndexE == mstatus)
                CSRFile[sc_item.CsrIndexE] <= X & `mstatus_mask;
            else if(sc_item.CsrIndexE == mtvec)
                CSRFile[sc_item.CsrIndexE] <= X & `align_mask;
            else if(sc_item.CsrIndexE == mepc)
                CSRFile[sc_item.CsrIndexE] <= X & `align_mask;
            else if(sc_item.CsrIndexE == mscratch)
                CSRFile[sc_item.CsrIndexE] <= X & `align_mask;
            else if(sc_item.CsrIndexE == mie)
                CSRFile[sc_item.CsrIndexE] <= X & `mie_mask;
            else if(sc_item.CsrIndexE == mip)
                CSRFile[sc_item.CsrIndexE] <= X & `mpie_mask;
            else if(sc_item.CsrIndexE == mcause)
                CSRFile[sc_item.CsrIndexE] <= CSRFile[sc_item.CsrIndexE];
            else if (sc_item.CsrIndexE == fflags)
            begin
                CSRFile[sc_item.CsrIndexE][4:0] <= X;
                CSRFile[fcsr][4:0] <= X;
            end
            else if( sc_item.CsrIndexE == frm)
            begin
                CSRFile[sc_item.CsrIndexE][2:0] <= X;
                CSRFile[fcsr][7:5] <= X;
            end
            else if( sc_item.CsrIndexE == fcsr)
            begin
                CSRFile[sc_item.CsrIndexE][7:0] <= X;
            end
            else if(sc_item.CsrIndexE != misa || sc_item.CsrIndexE != mvendorid)
                CSRFile[sc_item.CsrIndexE] <= X;
        endfunction:UpdateCsr

        function void CSRInterruptOperation ();
            if(
                (sc_item.TimerInterrupt & CSRFile[mstatus][`MIE] & CSRFile[mie][`MT_PIE]) ||
                (sc_item.ExternalInterrupt & CSRFile[mstatus][`MIE] & CSRFile[mie][`ME_PIE]) ||
                (sc_item.SoftwareInterrupt & CSRFile[mstatus][`MIE] & CSRFile[mie][`MS_PIE])
              )
            begin:InterruptHandling
                CSRFile[mstatus][`MPIE] = CSRFile[mstatus][`MIE];
                CSRFile[mstatus][`MIE] = 1'b0;
                CSRFile[mepc] = sc_item.PCPlus4E;
                TrapIsSet = 1'b1;
                if(sc_item.TimerInterrupt)
                begin
                    CSRFile[mcause] = {20'b0 , StoreAddressFaultOrMachineTimerInterrupt };
                    CsrOutPC = CSRFile[mtvec] + 4 * `MT_PIE;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(sc_item.ExternalInterrupt)
                begin
                    CSRFile[mcause] = {20'b0 , EcallMOrMachineExternalInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `ME_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(sc_item.SoftwareInterrupt)
                begin
                    CSRFile[mcause] = {20'b0 , BreakpointOrMachineSoftwareInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `MS_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                end
            end:InterruptHandling
        endfunction:CSRInterruptOperation

        function void CSROperation ();
            if
            (
                CSRFile[mstatus][`MIE] && 
                (
                    (CSRFile[mip][`MS_PIE] & CSRFile[mie][`MS_PIE])
                    || (CSRFile[mip][`MT_PIE] & CSRFile[mie][`MT_PIE])
                    || (CSRFile[mip][`ME_PIE] & CSRFile[mie][`ME_PIE])
                )
            )
            begin:InterruptPending
                CSRFile[mstatus][`MPIE] = CSRFile[mstatus][`MIE];
                CSRFile[mstatus][`MIE] = 1'b0;
                CSRFile[mepc] = sc_item.PCPlus4E;
                TrapIsSet = 1'b1;
                if(CSRFile[mip][`MT_PIE] & CSRFile[mie][`MT_PIE])
                begin
                    CSRFile[mcause] = {20'b0 , StoreAddressFaultOrMachineTimerInterrupt };
                    CsrOutPC = CSRFile[mtvec] + 4 * `MT_PIE;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(CSRFile[mip][`ME_PIE] & CSRFile[mie][`ME_PIE])
                begin
                    CSRFile[mcause] = {20'b0 , EcallMOrMachineExternalInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `ME_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.SoftwareInterrupt)
                        CSRFile[mip][`MS_PIE] = 1'b1;
                end
                else if(CSRFile[mip][`MS_PIE] & CSRFile[mie][`MS_PIE])
                begin
                    CSRFile[mcause] = {20'b0 , BreakpointOrMachineSoftwareInterrupt};
                    CsrOutPC = CSRFile[mtvec] + 4 * `MS_PIE;
                    if(sc_item.TimerInterrupt)
                        CSRFile[mip][`MT_PIE] = 1'b1;
                    if(sc_item.ExternalInterrupt)
                        CSRFile[mip][`ME_PIE] = 1'b1;
                end
            end:InterruptPending
            else if(|int'(Traps))
            begin:TrapHandling
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
                CSRFile[mcause] = {20'b0 , Traps};
                CSRFile[mepc] = sc_item.PCPlus4E;
                CsrOutPC = CSRFile[mtvec];
                CSRFile[mstatus][`MPIE] = CSRFile[mstatus][`MIE];
                CSRFile[mstatus][`MIE] = 1'b0;
                CSRFile[mbadaddr] = ALUOutE[FINAL_ADDR_WIDTH-1:0];
                TrapIsSet = 1'b1;
            end:TrapHandling
            else if(sc_item.MRetE)
            begin:ReturnFunction
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
                CSRFile[mstatus][`MIE] = CSRFile[mstatus][`MPIE];
                CSRFile[mstatus][`MPIE] = 1'b1;
                CsrOutPC = CSRFile[mepc];
                TrapIsSet = 1'b0;
                if(CSRFile[mstatus][`MPIE])
                begin:Delete_Pending
                    if(CSRFile[mcause] == {20'b0, EcallMOrMachineExternalInterrupt})
                    begin
                        CSRFile[mip][`ME_PIE] = 1'b0;
                    end
                    else if(CSRFile[mcause] == {20'b0, BreakpointOrMachineSoftwareInterrupt})
                    begin
                        CSRFile[mip][`MS_PIE] = 1'b0;
                    end
                    else if(CSRFile[mcause] == {20'b0, StoreAddressFaultOrMachineTimerInterrupt})
                    begin
                        CSRFile[mip][`MT_PIE] = 1'b0;
                    end
                end:Delete_Pending
            end:ReturnFunction
            else if(sc_item.CsrAccessE)
            begin:CSR_Access
                TrapIsSet = 1'b0;
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
                CsrOutM = CSRFile[sc_item.CsrIndexE];
                case(sc_item.CsrOperationE)
                    csrrw: 
                    begin
                        UpdateCsr($signed(sc_item.RD1E));
                    end
                    csrrs: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] | $unsigned(sc_item.RD1E));
                    end
                    csrrc: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] & ~$unsigned(sc_item.RD1E));
                    end
                    csrrwi: 
                    begin
                        UpdateCsr({27'b0, $unsigned(sc_item.RD1E)});
                    end
                    csrrsi: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] | {27'b0, $unsigned(sc_item.Rs1E)});
                    end
                    csrrci: 
                    begin
                        UpdateCsr(CSRFile[sc_item.CsrIndexE] & ~{27'b0, $unsigned(sc_item.Rs1E)});
                    end
                endcase
            end:CSR_Access
            else
            begin:Normal
                TrapIsSet = 1'b0;
                if(sc_item.TimerInterrupt)
                    CSRFile[mip][`MT_PIE] = 1'b1;
                if(sc_item.ExternalInterrupt)
                    CSRFile[mip][`ME_PIE] = 1'b1;
                if(sc_item.SoftwareInterrupt)
                    CSRFile[mip][`MS_PIE] = 1'b1;
            end:Normal
        endfunction:CSROperation

        function void ref_model ();
            case(sc_item.ALUControlE)
                ADD : ALUOutE = SrcA + SrcB;
                SUB : ALUOutE = SrcA - SrcB;
                AND : ALUOutE = SrcA & SrcB;
                OR : ALUOutE = SrcA | SrcB;
                XOR : ALUOutE = SrcA ^ SrcB;
                SLT : ALUOutE = $signed(SrcA) < $signed(SrcB);
                SLTU : ALUOutE = $unsigned(SrcA) < $unsigned(SrcB);
                SLL : ALUOutE = SrcA << SrcB[LOG_WIDTH-1:0];
                SRL : ALUOutE = SrcA >> SrcB[LOG_WIDTH-1:0];
                SRA : ALUOutE = $signed(SrcA) >>> SrcB[LOG_WIDTH-1:0];
                MUL : ALUOutE = MulOutput[FINAL_DATA_WIDTH-1:0];
                MULH : ALUOutE = MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                MULHSU : ALUOutE = MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                MULHU : ALUOutE = $unsigned(MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                DIV : ALUOutE = DivOutput;
                REM : ALUOutE = RemOutput;
                DIVU : ALUOutE = DivOutput;
                REMU : ALUOutE = RemOutput;
                default : ALUOutE = 'b0;
            endcase

            CheckForTrap();

            foreach(CSRFile[i]) 
            begin
                if
                (
                    i != mstatus &&
                    i != misa &&
                    i != medeleg &&
                    i != mideleg &&
                    i != mie &&
                    i != mtvec &&
                    i != mscratch &&
                    i != mepc &&
                    i != mcause &&
                    i != mbadaddr &&
                    i != mip &&
                    i != mcycle &&
                    i != mhartid &&
                    i != mvendorid &&
                    i != fflags &&
                    i != frm &&
                    i != fcsr
                )
                CSRFile[i] = 0;
            end

            if(!sc_item.rst)
            begin
                ALUOutM = 'b0;
                WriteDataM = 'b0;
                RdM = zero;
                PCSrcE = 'b0;
                RegWriteM = 'b0;
                funct3M = 'b0;
                MemWriteM = 'b0;
                branch_true = 1'b0;
                ALUOutM_past = 'b0;
                PCPlus4M = 'b0;
                SelectorM = ALUToReg;
                CsrOutM = 'b0;
                TrapIsSet = 'b0;
                CsrOutPC = 'b0;
                CSRFile[mstatus] = 0;
                CSRFile[misa] = 32'h40_00_01_00;
                CSRFile[medeleg] = 0;
                CSRFile[mideleg] = 0;
                CSRFile[mie] = 0;
                CSRFile[mtvec] = 0;
                CSRFile[mscratch] = 0;
                CSRFile[mepc] = 0;
                CSRFile[mcause] = 0;
                CSRFile[mbadaddr] = 0;
                CSRFile[mip] = 0;
                CSRFile[mcycle] = 0;
                CSRFile[mhartid] = 0;
                CSRFile[mvendorid] = 32'h48_41_4E_4F;
                CSRFile[fflags] = 0;
                CSRFile[frm] = 0;
                CSRFile[fcsr] = 0;
                FPUOutM_past = 'b0;
            end
            else
            begin:NotReset
                RdM = sc_item.RdE;
                RegWriteM = sc_item.RegWriteE;
                funct3M = sc_item.funct3E;
                MemWriteM = sc_item.MemWriteE;
                branch_true = 1'b0;
                PCSrcE = 'b0;
                PCPlus4M = sc_item.PCPlus4E;
                SelectorM = sc_item.SelectorE;
                
                CSROperation();

                case(sc_item.ForwardAE)
                    3'b000 : SrcA = sc_item.RD1E;
                    3'b001 : SrcA = sc_item.ResultW;
                    3'b010 : SrcA = ALUOutM_past;
                    3'b011 : SrcA = sc_item.FPUOutW;
                    3'b100 : SrcA = FPUOutM_past;
                    default : SrcA = 'b0;
                endcase

                case(sc_item.ForwardBE)
                    3'b000 : IntermediateB = sc_item.RD2E;
                    3'b001 : IntermediateB = sc_item.ResultW;
                    3'b010 : IntermediateB = ALUOutM_past;
                    3'b011 : IntermediateB = sc_item.FPUOutW;
                    3'b100 : IntermediateB = FPUOutM_past;
                    default : IntermediateB = 'b0;
                endcase


                WriteDataM = IntermediateB;

                case(sc_item.ALUSrcE)
                    1'b0 : SrcB = IntermediateB;
                    1'b1 : SrcB = sc_item.SignImmE;
                endcase

                SrcBU = SrcB;
                case(sc_item.ALUControlE)
                    MUL : MulOutput = $signed(SrcA) * $signed(SrcB);
                    MULH : MulOutput = $signed(SrcA) * $signed(SrcB);
                    MULHSU : MulOutput = {{FINAL_DATA_WIDTH{SrcA[FINAL_DATA_WIDTH-1]}},SrcA} * {{FINAL_DATA_WIDTH{1'b0}},SrcB};
                    MULHU : MulOutput = $unsigned(SrcA) * $unsigned(SrcB);
                    DIV : 
                    begin
                        if(SrcB == 0)
                            DivOutput = -1;
                        else if((SrcA == -2**(FINAL_DATA_WIDTH-1)) && (SrcB == -1))
                            DivOutput = SrcA;
                        else
                            DivOutput = ($signed(SrcA) / $signed(SrcB));
                    end
                    DIVU : 
                    begin
                        if(SrcB == 0)
                            DivOutput = -1;
                        else
                            DivOutput = ($unsigned(SrcA) / $unsigned(SrcB));
                    end
                    REM : 
                    begin
                        if(SrcB == 0)
                            RemOutput = SrcA;
                        else if((SrcA == -2**(FINAL_DATA_WIDTH-1)) && (SrcB == -1))
                            RemOutput = 0;
                        else
                            RemOutput = $signed(SrcA) % $signed(SrcB);
                    end
                    REMU : 
                    begin
                        if(SrcB == 0)
                            RemOutput = SrcA;
                        else
                            RemOutput = $unsigned(SrcA) % $unsigned(SrcB);
                    end
                endcase

                case(sc_item.ALUControlE)
                    ADD : ALUOutM = SrcA + SrcB;
                    SUB : ALUOutM = SrcA - SrcB;
                    AND : ALUOutM = SrcA & SrcB;
                    OR : ALUOutM = SrcA | SrcB;
                    XOR : ALUOutM = SrcA ^ SrcB;
                    SLT : ALUOutM = $signed(SrcA) < $signed(SrcB);
                    SLTU : ALUOutM = $unsigned(SrcA) < $unsigned(SrcB);
                    SLL : ALUOutM = $unsigned(SrcA) << $unsigned(SrcB[LOG_WIDTH-1:0]);
                    SRL : ALUOutM = $unsigned(SrcA) >> $unsigned(SrcB[LOG_WIDTH-1:0]);
                    SRA : ALUOutM = $signed(SrcA) >>> $unsigned(SrcB[LOG_WIDTH-1:0]);
                    MUL : ALUOutM = MulOutput[FINAL_DATA_WIDTH-1:0];
                    MULH : ALUOutM = MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                    MULHSU : ALUOutM = $signed(MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                    MULHU : ALUOutM = $unsigned(MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                    DIV : ALUOutM = DivOutput;
                    REM : ALUOutM = RemOutput;
                    DIVU : ALUOutM = $unsigned(DivOutput);
                    REMU : ALUOutM = RemOutput;
                endcase

                case(branch_t'(sc_item.funct3E))
                    BEQ : begin
                                if(SrcA == SrcB)
                                    branch_true = sc_item.BranchE;
                            end
                    BNE : begin
                                if(SrcA != SrcB)
                                    branch_true = sc_item.BranchE;
                            end
                    BLT : begin
                                if($signed(SrcA) < $signed(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BGE : begin
                                if($signed(SrcA) >= $signed(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BLTU : begin
                                if($unsigned(SrcA) < $unsigned(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BGEU : begin
                                if($unsigned(SrcA) >= $unsigned(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                endcase

                PCSrcE = (sc_item.BranchE & branch_true) || sc_item.JumpE;
                ALUOutM_past = sc_item.ALUOutM;
                FPUOutM_past = sc_item.FPUOutM;
                
                CSRInterruptOperation();
                
                check_output();

            end:NotReset
        endfunction:ref_model

        function void check_output ();
            if (
                ALUOutM[FINAL_DATA_WIDTH-1:0] != sc_item.ALUOutM || 
                WriteDataM != sc_item.WriteDataM || 
                RdM != sc_item.RdM || 
                PCSrcE != sc_item.PCSrcE ||
                RegWriteM != sc_item.RegWriteM || 
                funct3M != sc_item.funct3M || 
                MemWriteM != sc_item.MemWriteM ||
                CsrOutM != sc_item.CsrOutM ||
                PCPlus4M != sc_item.PCPlus4M ||
                SelectorM != sc_item.SelectorM ||
                TrapIsSet != sc_item.TrapIsSet ||
                CsrOutPC != sc_item.CsrOutPC
                ) 
            begin
                $display("///////////////////////Error occured in the Execute scoreboard///////////////////////");
                `uvm_info("SCB",{sc_item.convert2str,$sformatf(" and the past ALUOutM = %0d",ALUOutM_past)},UVM_HIGH)
                if (ALUOutM[FINAL_DATA_WIDTH-1:0] != sc_item.ALUOutM) begin
                    `uvm_info("SCB", $sformatf("Actual output ALUOutM = %0d -- ALUOutM = %0d , SrcA = %0d , SrcB = %0d", sc_item.ALUOutM, ALUOutM[FINAL_DATA_WIDTH-1:0], SrcA, SrcB), UVM_MEDIUM)
                    $display("SrcA = %0d , SrcB = %0d , MultiplyOut = %0d Operation %s",SrcA,SrcB,MulOutput,sc_item.ALUControlE.name());
                    fail++;
                end
                if (WriteDataM != sc_item.WriteDataM) begin
                    `uvm_info("SCB", $sformatf("Actual output WriteDataM = %0h -- WriteDataM = %0h", sc_item.WriteDataM, WriteDataM), UVM_MEDIUM)
                    fail++;
                end
                if (RdM != sc_item.RdM) begin
                    `uvm_info("SCB", $sformatf("Actual output RdM = %s -- RdM = %s", sc_item.RdM.name, RdM.name), UVM_MEDIUM)
                    fail++;
                end
                if (PCSrcE != sc_item.PCSrcE) begin
                    `uvm_info("SCB", $sformatf("Actual output PCSrcE = %0h -- PCSrcE = %0h", sc_item.PCSrcE, PCSrcE), UVM_MEDIUM)
                    fail++;
                end
                if (RegWriteM != sc_item.RegWriteM) begin
                    `uvm_info("SCB", $sformatf("Actual output RegWriteM = %0h -- RegWriteM = %0h", sc_item.RegWriteM, RegWriteM), UVM_MEDIUM)
                    fail++;
                end
                if (funct3M != sc_item.funct3M) begin
                    `uvm_info("SCB", $sformatf("Actual output funct3M = %0h -- funct3M = %0h", sc_item.funct3M, funct3M), UVM_MEDIUM)
                    fail++;
                end
                if (MemWriteM != sc_item.MemWriteM) begin
                    `uvm_info("SCB", $sformatf("Actual output MemWriteM = %0h -- MemWriteM = %0h", sc_item.MemWriteM, MemWriteM), UVM_MEDIUM)
                    fail++;
                end
                if (CsrOutM != sc_item.CsrOutM) begin
                    `uvm_info("SCB", $sformatf("Actual output CsrOutM = %0h -- CsrOutM = %0h", sc_item.CsrOutM, CsrOutM), UVM_MEDIUM)
                    fail++;
                end
                if (PCPlus4M != sc_item.PCPlus4M) begin
                    `uvm_info("SCB", $sformatf("Actual output PCPlus4M = %0h -- PCPlus4M = %0h", sc_item.PCPlus4M, PCPlus4M), UVM_MEDIUM)
                    fail++;
                end
                if (SelectorM != sc_item.SelectorM) begin
                    `uvm_info("SCB", $sformatf("Actual output SelectorM = %0h -- SelectorM = %0h", sc_item.SelectorM, SelectorM), UVM_MEDIUM)
                    fail++;
                end
                if (TrapIsSet != sc_item.TrapIsSet) begin
                    `uvm_info("SCB", $sformatf("Actual output TrapIsSet = %0h -- TrapIsSet = %0h ", sc_item.TrapIsSet, TrapIsSet), UVM_MEDIUM)
                    fail++;
                    `uvm_info("SCB",sc_item.convert2str(),UVM_MEDIUM)
                end
                if (CsrOutPC != sc_item.CsrOutPC) begin
                    `uvm_info("SCB", $sformatf("Actual output CsrOutPC = %0h -- CsrOutPC = %0h", sc_item.CsrOutPC, CsrOutPC), UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (execute_item item);
            sc_item = item;
            ref_model();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","sc_itemoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:execute_scoreboard

endpackage:execute_scoreboard_pkg
