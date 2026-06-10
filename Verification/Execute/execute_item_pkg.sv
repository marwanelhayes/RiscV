// =============================================================================
// execute_item_pkg.sv
// -----------------------------------------------------------------------------
// Execute stage sequence item package for UVM verification.
// =============================================================================
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
        rand logic FPUValidE;
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
        logic FPUBusyM;
        logic FPUDoneM;

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


        virtual function string convert2str();
            BranchControl = branch_t'(funct3E);
            return $sformatf("Inputs: rst = %0d | RD1E = %0d | RD2E = %0d | JumpE = %0d | SignImmE = %0d | Rs1E = %s | RdE = %s | ALU = %s | Br = %s | funct3 = %0d | RegWriteE = %0d | CsrAccessE = %0d | CsrOp = %s
            Outputs: ALUOutM = %0h | WriteDataM = %0h | RdM = %s | PCSrcE = %0d | RegWriteM = %0d | SelectorM = %s | MemWriteM = %0d",
            rst,RD1E,RD2E,JumpE,SignImmE,Rs1E.name(),RdE.name(),
            ALUControlE.name(),BranchControl.name(),funct3E,RegWriteE,CsrAccessE,CsrOperationE.name(),
            ALUOutM,WriteDataM,RdM.name(),PCSrcE,RegWriteM,SelectorM.name(),MemWriteM);
        endfunction:convert2str
        
        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            execute_item other;
            bit ok;
            bit super_ok;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not an execute_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok
                && (this.ALUOutM        === other.ALUOutM)
                && (this.WriteDataM     === other.WriteDataM)
                && (this.RdM            === other.RdM)
                && (this.PCSrcE         === other.PCSrcE)
                && (this.RegWriteM      === other.RegWriteM)
                && (this.PCPlus4M       === other.PCPlus4M)
                && (this.SelectorM      === other.SelectorM)
                && (this.funct3M        === other.funct3M)
                && (this.MemWriteM      === other.MemWriteM);
            
            if(this.ALUOutM !== other.ALUOutM)
                `uvm_info("ALUOutM Mismatch", $sformatf("Expected: %0d/%0h Actual: %0d/%0h", other.ALUOutM,other.ALUOutM, this.ALUOutM, this.ALUOutM), UVM_LOW)
            if(this.WriteDataM !== other.WriteDataM)
                `uvm_info("WriteDataM Mismatch", $sformatf("Expected: %0h Actual: %0h",other.WriteDataM,this.WriteDataM), UVM_LOW)
            if(this.RdM !== other.RdM)
                `uvm_info("RdM Mismatch", $sformatf("Expected: %s Actual: %s",other.RdM.name(),this.RdM.name()), UVM_LOW)
            if(this.PCSrcE !== other.PCSrcE)
                `uvm_info("PCSrcE Mismatch", $sformatf("Expected: %0d Actual: %0d",other.PCSrcE,this.PCSrcE), UVM_LOW)
            if(this.RegWriteM !== other.RegWriteM)
                `uvm_info("RegWriteM Mismatch", $sformatf("Expected: %0d Actual: %0d",other.RegWriteM,this.RegWriteM), UVM_LOW)
            if(this.PCPlus4M !== other.PCPlus4M)
                `uvm_info("PCPlus4M Mismatch", $sformatf("Expected: %0h Actual: %0h",other.PCPlus4M,this.PCPlus4M), UVM_LOW)
            if(this.SelectorM !== other.SelectorM)
                `uvm_info("SelectorM Mismatch", $sformatf("Expected: %s Actual: %s",other.SelectorM.name(),this.SelectorM.name()), UVM_LOW)
            if(this.funct3M !== other.funct3M)
                `uvm_info("funct3M Mismatch", $sformatf("Expected: %0d Actual: %0d",other.funct3M,this.funct3M), UVM_LOW)
            if(this.MemWriteM !== other.MemWriteM)
                `uvm_info("MemWriteM Mismatch", $sformatf("Expected: %0d Actual: %0d",other.MemWriteM,this.MemWriteM), UVM_LOW)
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            execute_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("do_copy","rhs is not an execute_item")
                return;
            end
            super.do_copy(rhs);
            this.rst                 = other.rst;
            this.RD1E                = other.RD1E;
            this.RD2E                = other.RD2E;
            this.SignImmE            = other.SignImmE;
            this.ResultW             = other.ResultW;
            this.PCPlus4E            = other.PCPlus4E;
            this.ALUControlE         = other.ALUControlE;
            this.funct3E             = other.funct3E;
            this.BranchE             = other.BranchE;
            this.JumpE               = other.JumpE;
            this.ForwardAE           = other.ForwardAE;
            this.ForwardBE           = other.ForwardBE;
            this.Rs1E                = other.Rs1E;
            this.RdE                 = other.RdE;
            this.RegWriteE           = other.RegWriteE;
            this.CsrAccessE          = other.CsrAccessE;
            this.CsrOperationE       = other.CsrOperationE;
            this.CsrIndexE           = other.CsrIndexE;
            this.SelectorE           = other.SelectorE;
            this.ALUSrcE             = other.ALUSrcE;
            this.MemWriteE           = other.MemWriteE;
            this.MRetE               = other.MRetE;
            this.EcallE              = other.EcallE;
            this.EbreakE             = other.EbreakE;
            this.IllegaleInstructionE= other.IllegaleInstructionE;
            this.TimerInterrupt      = other.TimerInterrupt;
            this.SoftwareInterrupt   = other.SoftwareInterrupt;
            this.ExternalInterrupt   = other.ExternalInterrupt;
            this.RdFE                = other.RdFE;
            this.RD1FE               = other.RD1FE;
            this.RD2FE               = other.RD2FE;
            this.FPUControlE         = other.FPUControlE;
            this.RoundModeE          = other.RoundModeE;
            this.FPURegWriteE        = other.FPURegWriteE;
            this.FPUValidE           = other.FPUValidE;
            this.MoveOperationE      = other.MoveOperationE;
            this.FPUOutW             = other.FPUOutW;
            this.ForwardFloatingAE   = other.ForwardFloatingAE;
            this.ForwardFloatingBE   = other.ForwardFloatingBE;
            this.Rs1FE               = other.Rs1FE;
            this.Rs2FE               = other.Rs2FE;
            
            this.ALUOutM             = other.ALUOutM;
            this.WriteDataM          = other.WriteDataM;
            this.RdM                 = other.RdM;
            this.PCSrcE              = other.PCSrcE;
            this.RegWriteM           = other.RegWriteM;
            this.PCPlus4M            = other.PCPlus4M;
            this.SelectorM           = other.SelectorM;
            this.funct3M             = other.funct3M;
            this.CsrOutM             = other.CsrOutM;
            this.MemWriteM           = other.MemWriteM;
            this.TrapIsSet           = other.TrapIsSet;
            this.CsrOutPC            = other.CsrOutPC;
            this.RdFM                = other.RdFM;
            this.OverflowM           = other.OverflowM;
            this.UnderflowM          = other.UnderflowM;
            this.NaNM                = other.NaNM;
            this.InfM                = other.InfM;
            this.ZeroM               = other.ZeroM;
            this.InvalidDivM         = other.InvalidDivM;
            this.FPUOutM             = other.FPUOutM;
            this.FPURegWriteM        = other.FPURegWriteM;
            this.MoveOperationM      = other.MoveOperationM;
            this.FPUBusyM            = other.FPUBusyM;
            this.FPUDoneM            = other.FPUDoneM;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            execute_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("copy_inputs","rhs is not an execute_item")
                return;
            end
            this.rst                 = other.rst;
            this.RD1E                = other.RD1E;
            this.RD2E                = other.RD2E;
            this.SignImmE            = other.SignImmE;
            this.ResultW             = other.ResultW;
            this.PCPlus4E            = other.PCPlus4E;
            this.ALUControlE         = other.ALUControlE;
            this.funct3E             = other.funct3E;
            this.BranchE             = other.BranchE;
            this.JumpE               = other.JumpE;
            this.ForwardAE           = other.ForwardAE;
            this.ForwardBE           = other.ForwardBE;
            this.Rs1E                = other.Rs1E;
            this.RdE                 = other.RdE;
            this.RegWriteE           = other.RegWriteE;
            this.CsrAccessE          = other.CsrAccessE;
            this.CsrOperationE       = other.CsrOperationE;
            this.CsrIndexE           = other.CsrIndexE;
            this.SelectorE           = other.SelectorE;
            this.ALUSrcE             = other.ALUSrcE;
            this.MemWriteE           = other.MemWriteE;
            this.MRetE               = other.MRetE;
            this.EcallE              = other.EcallE;
            this.EbreakE             = other.EbreakE;
            this.IllegaleInstructionE= other.IllegaleInstructionE;
            this.TimerInterrupt      = other.TimerInterrupt;
            this.SoftwareInterrupt   = other.SoftwareInterrupt;
            this.ExternalInterrupt   = other.ExternalInterrupt;
            this.RdFE                = other.RdFE;
            this.RD1FE               = other.RD1FE;
            this.RD2FE               = other.RD2FE;
            this.FPUControlE         = other.FPUControlE;
            this.RoundModeE          = other.RoundModeE;
            this.FPURegWriteE        = other.FPURegWriteE;
            this.FPUValidE           = other.FPUValidE;
            this.MoveOperationE      = other.MoveOperationE;
            this.FPUOutW             = other.FPUOutW;
            this.ForwardFloatingAE   = other.ForwardFloatingAE;
            this.ForwardFloatingBE   = other.ForwardFloatingBE;
            this.Rs1FE               = other.Rs1FE;
            this.Rs2FE               = other.Rs2FE;
        endfunction:copy_inputs

    endclass: execute_item
endpackage:execute_item_pkg
