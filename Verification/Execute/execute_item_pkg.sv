package execute_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class execute_item extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_utils(execute_item)

        //Overriding the build in constructor with the child class
        function new (string name = "execute_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand logic signed [FINAL_DATA_WIDTH-1:0] RD1E;
        rand logic signed [FINAL_DATA_WIDTH-1:0] RD2E;
        rand logic signed [FINAL_DATA_WIDTH-1:0] SignImmE;
        rand logic signed [FINAL_DATA_WIDTH-1:0] ResultW;
        rand logic [FINAL_ADDR_WIDTH-1:0] PCPlus4E;
        rand alu_operation_t ALUControlE;
        rand logic [2:0] funct3E;
        rand logic BranchE;
        rand logic JumpE;
        rand logic [2:0] ForwardAE;
        rand logic [2:0] ForwardBE;
        rand gpr_t Rs1E;
        rand gpr_t RdE;
        rand logic RegWriteE;
        rand logic CsrAccessE;
        rand csr_t CsrOperationE;
        rand csr_index_t CsrIndexE;
        rand selector_t SelectorE;
        rand logic ALUSrcE;
        rand logic MemWriteE;
        rand logic MRetE;
        rand logic EcallE;
        rand logic EbreakE;
        rand logic IllegaleInstructionE;
        rand logic TimerInterrupt;
        rand logic SoftwareInterrupt;
        rand logic ExternalInterrupt;
        rand fpr_t RdFE;
        rand logic [FINAL_DATA_WIDTH-1:0] RD1FE;
        rand logic [FINAL_DATA_WIDTH-1:0] RD2FE;
        rand fpu_operation_t FPUControlE;
        rand round_mode_t RoundModeE;
        rand logic FPURegWriteE;
        rand move_operation_t MoveOperationE;
        rand logic [FINAL_DATA_WIDTH-1:0] FPUOutW;
        rand logic [1:0] ForwardFloatingAE;
        rand logic [1:0] ForwardFloatingBE;
        rand fpr_t Rs1FE;
        rand fpr_t Rs2FE;

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
        fpr_t RdFM;
        logic OverflowM;
        logic UnderflowM;
        logic NaNM;
        logic InfM;
        logic ZeroM;
        logic InvalidDivM;
        logic [FINAL_DATA_WIDTH-1:0] FPUOutM;
        logic FPURegWriteM;
        move_operation_t MoveOperationM;

        branch_t BranchControl;
        


        //Insert random resets at random times
        constraint LowResetProb 
        {
            rst dist {0:=5,1:=1000};
        }

        //Forbid writing to zero register
        constraint NoZeroReg 
        {       
            !(RdE inside{zero});
        }

        constraint ForwaradingA 
        {
            ForwardAE  inside {3'b0,3'b001,3'b010,3'b011 ,3'b100};
        }

        constraint ForwaradingB 
        {
            ForwardBE inside {3'b0,3'b001,3'b010,3'b011 ,3'b100};
        }

        constraint ForwaradingFloatingA 
        {
            ForwardFloatingAE != 2'b11;
        }

        constraint ForwaradingFloatingB 
        {
            ForwardFloatingBE != 2'b11;
        }

        constraint Branching 
        {
            if(BranchE)
            {
                if(funct3E[1] && funct3E[2])
                {
                    ALUControlE == SLTU;
                }
                else
                {
                    ALUControlE == SUB;
                }
            }
        }

        constraint CantEqualize
        {
            RegWriteE != FPURegWriteE;
        }

        constraint CrossWriting
        {
            if(MoveOperationE == FPUToReg)
            {
                RegWriteE == 1'b1;
            }

            if((MoveOperationE == RegToFPU) || (MoveOperationE == FPUToFPU))
            {
                FPURegWriteE == 1'b1;
            }
        }

        constraint CrossOperation
        {
            if((FPUControlE == FCVT_S_W) || (FPUControlE == FCVT_S_WU) || (FPUControlE == FMV_S_X))
            {
                MoveOperationE == RegToFPU;
            }
            else if((FPUControlE == FCVT_W_S) || (FPUControlE == FCVT_WU_S) || (FPUControlE == FMV_X_S))
            {
                MoveOperationE == FPUToReg;
            }
            else
            {
                MoveOperationE == FPUToFPU;
            }
        }

        /*constraint FPUNoDivision
        {
            FPUControlE != FDIV_S;
        }*/

        virtual function string convert2str();
            BranchControl = branch_t'(funct3E);
            return $sformatf("The inputs of the transaction are rst = %0d , RD1E = %0d , RD2E = %0d , JumpE = %0d , SignImmE = %0d, Writeback Result = %0d , ALU control = %s , Branch control = %s , Funct3 = %0d , Branch = %0d , Forward AE = %b , Forward BE = %b , ALUSrcE = %b , MemWriteE = %b , CsrAccess = %0d, CsrOperation = %s, CsrIndex = %s, Selector = %s , PCPlus4E = %0d , Rs1E = %s , MRetE = %b , EcallE = %b , EbreakE = %b , IllegaleInstructionE = %b , TimerInterrupt = %b , SoftwareInterrupt = %b , ExternalInterrupt = %b , RdfE = %s , RD1FE = %0d , RD2FE = %0d , FPUControlE = %s , RoundModeE = %s , FPURegWriteE = %b , MoveOperationE = %s , FPUOutW = %0d , ForwardFloatingAE = %b , ForwardFloatingBE = %b , Rs1FE = %s , Rs2FE = %s and the outputs are ALUOutM = %0d , WriteDataM = %0d , RdM = %0d , PCSrcE = %b , RegWriteM = %b , funct3M = %0d , MemWriteM = %0b , CsrOutM = %0d , PCPlus4M = %0d , SelectorM = %s , TrapIsSet = %b , CsrOutPC = %0d , RdFM = %s , OverflowM = %b , UnderflowM = %b , NaNM = %b , InfM = %b , ZeroM = %b , InvalidDivM = %b , FPUOutM = %0d , FPURegWriteM = %b , MoveOperationM = %s",rst, RD1E, RD2E, JumpE, SignImmE, ResultW, ALUControlE, BranchControl.name(), funct3E, BranchE, ForwardAE, ForwardBE, ALUSrcE, MemWriteE, CsrAccessE, CsrOperationE.name(), CsrIndexE.name(), SelectorE.name(), PCPlus4E, Rs1E.name(), MRetE, EcallE, EbreakE, IllegaleInstructionE, TimerInterrupt, SoftwareInterrupt, ExternalInterrupt,RdFE.name(), RD1FE, RD2FE, FPUControlE.name(), RoundModeE.name(), FPURegWriteE, MoveOperationE.name(), FPUOutW, ForwardFloatingAE, ForwardFloatingBE, Rs1FE.name(), Rs2FE.name(),/*The outputs*/ALUOutM, WriteDataM, RdM, PCSrcE, RegWriteM, funct3M, MemWriteM, CsrOutM, PCPlus4M, SelectorM.name(), TrapIsSet, CsrOutPC , RdFM.name(), OverflowM, UnderflowM, NaNM, InfM, ZeroM, InvalidDivM, FPUOutM, FPURegWriteM, MoveOperationM.name());
        endfunction: convert2str
    endclass: execute_item
endpackage:execute_item_pkg