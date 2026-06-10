// =============================================================================
// decode_item_pkg.sv
// -----------------------------------------------------------------------------
// Decode stage sequence item package for UVM verification.
// =============================================================================
package decode_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class decode_item extends uvm_sequence_item;

        rand logic rst;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D = 0;
        rand logic [FINAL_DATA_WIDTH-1:0] InstructionD;
        rand gpr_t RdW;
        rand logic FlushE;
        rand logic RegWriteW;
        rand logic signed [FINAL_DATA_WIDTH-1:0] ResultW;
        rand fpr_t RdFW;
        rand logic [FINAL_DATA_WIDTH-1:0] FPUOutW;
        rand move_operation_t MoveOperationW;
        rand logic FPURegWriteW;
        
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
        logic EcallE;
        logic EbreakE;
        logic MRetE;
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
        logic FPUValidE;
        
        opcode_t opcode;

        //Register the class in the factory
        `uvm_object_utils(decode_item)
            

        //Overriding the build in constructor with the child class
        function new (string name = "decode_item");
            super.new(name);
        endfunction: new
        


        //Insert random resets at random times
        constraint LowResetProb 
        {
            rst dist {0:=5,1:=200};
        }

        //Only allow the implemented instructions
        constraint ValidInstructions 
        {
            opcode_t'(InstructionD[6:0]) inside {R_TYPE,I_TYPE,S_TYPE,B_TYPE,LOAD,JAL,JALR,CSR,FLOATING_PT};
        }

        constraint SystemMode
        {
            ((opcode_t'(InstructionD[6:0]) == CSR) && (csr_t'(InstructionD[14:12]) == system))
            -> 
            (InstructionD[31:20] == 12'b0000_0000_0000 || InstructionD[31:20] == 12'b0000_0000_0001 || InstructionD[31:20] == 12'b0011_0000_0010);
        }

        constraint CsrMode
        {
            ((opcode_t'(InstructionD[6:0]) == CSR))
            -> 
            csr_t'(InstructionD[14:12]) inside {csrrw , csrrs , csrrc , csrrwi , csrrsi , csrrci , system};
        }

        //Constraint the funct 3 and funct 7 fields
        constraint RTypeFunct7 
        {
            (opcode_t'(InstructionD[6:0]) == R_TYPE) 
            -> 
            (InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b0 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_0000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0001);
        }

        constraint RTypeFunct3 
        {
            ((opcode_t'(InstructionD[6:0]) == R_TYPE) && (InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_0000))  
            -> 
            (InstructionD[14:12] == 3'b000 || InstructionD[14:12] == 3'b101);
        }

        constraint ITypeFunct3 
        {
            (opcode_t'(InstructionD[6:0]) == I_TYPE) 
            -> 
            (InstructionD[14:12] == 3'b000 || InstructionD[14:12] == 3'b010 || InstructionD[14:12] == 3'b011 || InstructionD[14:12] == 3'b111 || InstructionD[14:12] == 3'b110 || InstructionD[14:12] == 3'b100);
        }

        constraint STypeFunct3 
        {
            (opcode_t'(InstructionD[6:0]) == S_TYPE)
            ->
            (InstructionD[14:12] == 3'b000 || InstructionD[14:12] == 3'b001 || InstructionD[14:12] == 3'b010);
        }

        constraint LoadTypeFunct3
        {
            (opcode_t'(InstructionD[6:0]) == LOAD)
            ->
            (InstructionD[14:12] == 3'b000 || InstructionD[14:12] == 3'b001 || InstructionD[14:12] == 3'b010 || InstructionD[14:12] == 3'b100 || InstructionD[14:12] == 3'b101);
        }

        constraint BTypeFunct3 
        {
            (opcode_t'(InstructionD[6:0]) == B_TYPE)
            ->
            (InstructionD[14:12] == 3'b000 || InstructionD[14:12] == 3'b001 || InstructionD[14:12] == 3'b100 || InstructionD[14:12] == 3'b101 || InstructionD[14:12] == 3'b110 || InstructionD[14:12] == 3'b111);
        }

        constraint FTypeFunct7 
        {
            (opcode_t'(InstructionD[6:0]) == FLOATING_PT) 
            -> 
            (InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b0 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_0100 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_1000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b000_1100 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_1100 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0100 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_0000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_0000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b101_0000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_0000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_1000 || InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_1000 );
        }
        
        constraint FTypeFunct3 
        {
            if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b001_0000)
            {
                InstructionD[14:12] inside {3'b000,3'b001,3'b010};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_0000)
            {
                InstructionD[14:12] inside {3'b000 , 3'b001};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b101_0000) 
            {
                InstructionD[14:12] inside {3'b000,3'b001,3'b010};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_1000) 
            {
                InstructionD[14:12] inside {3'b000};
            }
        }

        constraint FTypeRs2 
        {
            if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b010_1100)
            {
                InstructionD[24:20] inside {5'b00000};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_0000)
            {
                InstructionD[24:20] inside {5'b00000 , 5'b00001};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_0000) 
            {
                InstructionD[24:20] inside {5'b00000};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b110_1000) 
            {
                InstructionD[24:20] inside {5'b00000 , 5'b00001};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[FINAL_DATA_WIDTH-1:25] == 7'b111_1000) 
            {
                InstructionD[24:20] inside {5'b00000};
            }
        }

        //Forbid writing to zero register
        constraint NoZeroReg 
        {       
            !(RdW inside{zero});
        }

        //Insert random flushes at random times
        constraint FlushEProb 
        {
            FlushE dist {0:=70,1:=30};
        }

        

        virtual function string convert2str();
            opcode = opcode_t'(InstructionD[6:0]);
            return $sformatf("\tInputs: rst = %0d | PCPlus4D = %0h | Opcode = %s | InstructionD = %0h | RdW = %s | FlushE = %0d | RegWriteW = %0d | ResultW = %0h | RdFW = %s | FPUOutW = %0h | MoveOperationW = %s | FPURegWriteW = %0d \n
            Outputs: Rs1E = %s | Rs2E = %s | Rs1D = %s | Rs2D = %s | RdE = %s | JumpE = %0h | ALUControlE = %s | 
            CsrOperationE = %s | RD1E = %0h | RD2E = %0h | SignImmE = %0h | PCBranchE = %0h | CsrIndexE = %s | 
            funct3E = %0h | PCPlus4E = %0h | RegWriteE = %0h | SelectorE = %s | MemWriteE = %0h | BranchE = %0h | 
            CsrAccessE = %0h | ALUSrcE = %0h | EcallE = %0h | EbreakE = %0h | MRetE =  %0h | IllegaleInstructionE = %0h |
            RdFE = %s | RD1FE = %0h | RD2FE = %0h | FPUControlE = %s | RoundModeE %s | FPURegWriteE = %0h | 
            MoveOperationE = %s | Rs1FE = %s | Rs2FE = %s | FPUValidE = %0h",
            rst,PCPlus4D,opcode.name(),InstructionD,RdW.name(),FlushE,RegWriteW,ResultW,RdFW.name(),FPUOutW,MoveOperationW.name(),FPURegWriteW,
            Rs1E.name(), Rs2E.name(), Rs1D.name(), Rs2D.name(), RdE.name(), JumpE, ALUControlE.name(), CsrOperationE.name(),RD1E, RD2E, SignImmE, PCBranchE, CsrIndexE.name(), funct3E, PCPlus4E,RegWriteE, SelectorE.name(), MemWriteE, BranchE, CsrAccessE, ALUSrcE, EcallE, EbreakE, MRetE, IllegaleInstructionE,RdFE.name(), RD1FE, RD2FE, FPUControlE.name(), RoundModeE.name(), FPURegWriteE,MoveOperationE.name(), Rs1FE.name(), Rs2FE.name(), FPUValidE);
        endfunction: convert2str

        function void post_randomize;
            PCPlus4D = PCPlus4D + 32'h4;
        endfunction: post_randomize

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            decode_item other;
            bit ok;
            bit super_ok;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a decode_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok
                && (this.Rs1E                 === other.Rs1E)
                && (this.Rs2E                 === other.Rs2E)
                && (this.Rs1D                 === other.Rs1D)
                && (this.Rs2D                 === other.Rs2D)
                && (this.RdE                  === other.RdE)
                && (this.JumpE                === other.JumpE)
                && (this.ALUControlE          === other.ALUControlE)
                && (this.CsrOperationE        === other.CsrOperationE)
                && (this.RD1E                 === other.RD1E)
                && (this.RD2E                 === other.RD2E)
                && (this.SignImmE             === other.SignImmE)
                && (this.PCBranchE            === other.PCBranchE)
                && (this.CsrIndexE            === other.CsrIndexE)
                && (this.funct3E              === other.funct3E)
                && (this.PCPlus4E             === other.PCPlus4E)
                && (this.RegWriteE            === other.RegWriteE)
                && (this.SelectorE            === other.SelectorE)
                && (this.MemWriteE            === other.MemWriteE)
                && (this.BranchE              === other.BranchE)
                && (this.CsrAccessE           === other.CsrAccessE)
                && (this.ALUSrcE              === other.ALUSrcE)
                && (this.EcallE               === other.EcallE)
                && (this.EbreakE              === other.EbreakE)
                && (this.MRetE                === other.MRetE)
                && (this.IllegaleInstructionE === other.IllegaleInstructionE)
                && (this.RdFE                 === other.RdFE)
                && (this.RD1FE                === other.RD1FE)
                && (this.RD2FE                === other.RD2FE)
                && (this.FPUControlE          === other.FPUControlE)
                && (this.RoundModeE           === other.RoundModeE)
                && (this.FPURegWriteE         === other.FPURegWriteE)
                && (this.MoveOperationE       === other.MoveOperationE)
                && (this.Rs1FE                === other.Rs1FE)
                && (this.Rs2FE                === other.Rs2FE)
                && (this.FPUValidE            === other.FPUValidE);

                if(this.Rs1E !== other.Rs1E)
                    `uvm_info("Rs1E Mismatch",$sformatf("Expected: %0h Actual: %0h",other.Rs1E,this.Rs1E), UVM_LOW)
                if(this.Rs2E !== other.Rs2E)
                    `uvm_info("Rs2E Mismatch",$sformatf("Expected: %0h Actual: %0h",other.Rs2E,this.Rs2E), UVM_LOW)
                if(this.Rs1D !== other.Rs1D)
                    `uvm_info("Rs1D Mismatch",$sformatf("Expected: %0h Actual: %0h",other.Rs1D,this.Rs1D), UVM_LOW)
                if(this.Rs2D !== other.Rs2D)
                    `uvm_info("Rs2D Mismatch",$sformatf("Expected: %0h Actual: %0h",other.Rs2D,this.Rs2D), UVM_LOW)
                if(this.RdE !== other.RdE)
                    `uvm_info("RdE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RdE,this.RdE), UVM_LOW)
                if(this.JumpE !== other.JumpE)
                    `uvm_info("JumpE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.JumpE,this.JumpE), UVM_LOW)
                if(this.ALUControlE !== other.ALUControlE)
                    `uvm_info("ALUControlE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.ALUControlE,this.ALUControlE), UVM_LOW)
                if(this.CsrOperationE !== other.CsrOperationE)
                    `uvm_info("CsrOperationE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.CsrOperationE,this.CsrOperationE), UVM_LOW)
                if(this.RD1E !== other.RD1E)
                    `uvm_info("RD1E Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RD1E,this.RD1E), UVM_LOW)
                if(this.RD2E !== other.RD2E)
                    `uvm_info("RD2E Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RD2E,this.RD2E), UVM_LOW)
                if(this.SignImmE !== other.SignImmE)
                    `uvm_info("SignImmE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.SignImmE,this.SignImmE), UVM_LOW)
                if(this.PCBranchE !== other.PCBranchE)
                    `uvm_info("PCBranchE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.PCBranchE,this.PCBranchE), UVM_LOW)
                if(this.CsrIndexE !== other.CsrIndexE)
                    `uvm_info("CsrIndexE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.CsrIndexE,this.CsrIndexE), UVM_LOW)
                if(this.funct3E !== other.funct3E)
                    `uvm_info("funct3E Mismatch",$sformatf("Expected: %0h Actual: %0h",other.funct3E,this.funct3E), UVM_LOW)
                if(this.PCPlus4E !== other.PCPlus4E)
                    `uvm_info("PCPlus4E Mismatch",$sformatf("Expected: %0h Actual: %0h",other.PCPlus4E,this.PCPlus4E), UVM_LOW)
                if(this.RegWriteE !== other.RegWriteE)
                    `uvm_info("RegWriteE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RegWriteE,this.RegWriteE), UVM_LOW)
                if(this.SelectorE !== other.SelectorE)
                    `uvm_info("SelectorE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.SelectorE,this.SelectorE), UVM_LOW)
                if(this.MemWriteE !== other.MemWriteE)
                    `uvm_info("MemWriteE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.MemWriteE,this.MemWriteE), UVM_LOW)
                if(this.BranchE !== other.BranchE)
                    `uvm_info("BranchE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.BranchE,this.BranchE), UVM_LOW)
                if(this.CsrAccessE !== other.CsrAccessE)
                    `uvm_info("CsrAccessE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.CsrAccessE,this.CsrAccessE), UVM_LOW)
                if(this.ALUSrcE !== other.ALUSrcE)
                    `uvm_info("ALUSrcE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.ALUSrcE,this.ALUSrcE), UVM_LOW)
                if(this.EcallE !== other.EcallE)
                    `uvm_info("EcallE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.EcallE,this.EcallE), UVM_LOW)
                if(this.EbreakE !== other.EbreakE)
                    `uvm_info("EbreakE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.EbreakE,this.EbreakE), UVM_LOW)
                if(this.MRetE !== other.MRetE)
                    `uvm_info("MRetE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.MRetE,this.MRetE), UVM_LOW)
                if(this.IllegaleInstructionE !== other.IllegaleInstructionE)
                    `uvm_info("IllegaleInstructionE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.IllegaleInstructionE,this.IllegaleInstructionE), UVM_LOW)
                if(this.RdFE !== other.RdFE)
                    `uvm_info("RdFE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RdFE,this.RdFE), UVM_LOW)
                if(this.RD1FE !== other.RD1FE)
                    `uvm_info("RD1FE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RD1FE,this.RD1FE), UVM_LOW)
                if(this.RD2FE !== other.RD2FE)
                    `uvm_info("RD2FE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RD2FE,this.RD2FE), UVM_LOW)
                if(this.FPUControlE !== other.FPUControlE)
                    `uvm_info("FPUControlE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.FPUControlE,this.FPUControlE), UVM_LOW)
                if(this.RoundModeE !== other.RoundModeE)
                    `uvm_info("RoundModeE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.RoundModeE,this.RoundModeE), UVM_LOW)
                if(this.FPURegWriteE !== other.FPURegWriteE)
                    `uvm_info("FPURegWriteE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.FPURegWriteE,this.FPURegWriteE), UVM_LOW)
                if(this.MoveOperationE !== other.MoveOperationE)
                    `uvm_info("MoveOperationE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.MoveOperationE,this.MoveOperationE), UVM_LOW)
                if(this.Rs1FE !== other.Rs1FE)
                    `uvm_info("Rs1FE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.Rs1FE,this.Rs1FE), UVM_LOW)
                if(this.Rs2FE !== other.Rs2FE)
                    `uvm_info("Rs2FE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.Rs2FE,this.Rs2FE), UVM_LOW)
                if(this.FPUValidE !== other.FPUValidE)
                    `uvm_info("FPUValidE Mismatch",$sformatf("Expected: %0h Actual: %0h",other.FPUValidE,this.FPUValidE), UVM_LOW)
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            decode_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("do_copy","rhs is not a decode_item")
                return;
            end
            super.do_copy(rhs);
            this.rst                  = other.rst;
            this.PCPlus4D             = other.PCPlus4D;
            this.InstructionD         = other.InstructionD;
            this.RdW                  = other.RdW;
            this.FlushE               = other.FlushE;
            this.RegWriteW            = other.RegWriteW;
            this.ResultW              = other.ResultW;
            this.RdFW                 = other.RdFW;
            this.FPUOutW              = other.FPUOutW;
            this.MoveOperationW       = other.MoveOperationW;
            this.FPURegWriteW         = other.FPURegWriteW;
            this.Rs1E                 = other.Rs1E;
            this.Rs2E                 = other.Rs2E;
            this.Rs1D                 = other.Rs1D;
            this.Rs2D                 = other.Rs2D;
            this.RdE                  = other.RdE;
            this.JumpE                = other.JumpE;
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
            this.BranchE              = other.BranchE;
            this.CsrAccessE           = other.CsrAccessE;
            this.ALUSrcE              = other.ALUSrcE;
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
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            decode_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("copy_inputs","rhs is not a decode_item")
                return;
            end
            this.rst                  = other.rst;
            this.PCPlus4D             = other.PCPlus4D;
            this.InstructionD         = other.InstructionD;
            this.RdW                  = other.RdW;
            this.FlushE               = other.FlushE;
            this.RegWriteW            = other.RegWriteW;
            this.ResultW              = other.ResultW;
            this.RdFW                 = other.RdFW;
            this.FPUOutW              = other.FPUOutW;
            this.MoveOperationW       = other.MoveOperationW;
            this.FPURegWriteW         = other.FPURegWriteW;
        endfunction:copy_inputs
    endclass: decode_item
endpackage:decode_item_pkg
