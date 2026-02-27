package decode_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class decode_item #(parameter int DATA_WIDTH = 32,ADDR_WIDTH = 32) extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_param_utils(decode_item #(DATA_WIDTH,ADDR_WIDTH))

        //Overriding the build in constructor with the child class
        function new (string name = "decode_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        logic [ADDR_WIDTH-1:0] PCPlus4D = 0;
        rand logic [DATA_WIDTH-1:0] InstructionD;
        rand gpr_t RdW;
        rand logic FlushE;
        rand logic RegWriteW;
        rand logic ForwardAD;
        rand logic ForwardBD;
        rand logic signed [DATA_WIDTH-1:0] ALUOutM;
        rand logic signed [DATA_WIDTH-1:0] ResultW;
        rand fpr_t RdFW;
        rand logic [DATA_WIDTH-1:0] FPUOutW;
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
        logic signed [DATA_WIDTH-1:0] RD1E;
        logic signed [DATA_WIDTH-1:0] RD2E;
        logic signed [DATA_WIDTH-1:0] SignImmE;
        logic [ADDR_WIDTH-1:0] PCBranchE;
        csr_index_t CsrIndexE;
        logic [2:0] funct3E;
        logic [ADDR_WIDTH-1:0] PCPlus4E;
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
        logic [DATA_WIDTH-1:0] RD1FE;
        logic [DATA_WIDTH-1:0] RD2FE;
        fpu_operation_t FPUControlE;
        round_mode_t RoundModeE;
        logic FPURegWriteE;
        move_operation_t MoveOperationE;
        fpr_t Rs1FE;
        fpr_t Rs2FE;
        
        opcode_t opcode;
        


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
            (InstructionD[DATA_WIDTH-1:25] == 7'b0 || InstructionD[DATA_WIDTH-1:25] == 7'b010_0000 || InstructionD[DATA_WIDTH-1:25] == 7'b000_0001);
        }

        constraint RTypeFunct3 
        {
            ((opcode_t'(InstructionD[6:0]) == R_TYPE) && (InstructionD[DATA_WIDTH-1:25] == 7'b010_0000))  
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
            (InstructionD[DATA_WIDTH-1:25] == 7'b0 || InstructionD[DATA_WIDTH-1:25] == 7'b000_0100 || InstructionD[DATA_WIDTH-1:25] == 7'b000_1000 || InstructionD[DATA_WIDTH-1:25] == 7'b000_1100 || InstructionD[DATA_WIDTH-1:25] == 7'b010_1100 || InstructionD[DATA_WIDTH-1:25] == 7'b001_0000 || InstructionD[DATA_WIDTH-1:25] == 7'b001_0100 || InstructionD[DATA_WIDTH-1:25] == 7'b110_0000 || InstructionD[DATA_WIDTH-1:25] == 7'b111_0000 || InstructionD[DATA_WIDTH-1:25] == 7'b101_0000 || InstructionD[DATA_WIDTH-1:25] == 7'b111_0000 || InstructionD[DATA_WIDTH-1:25] == 7'b110_1000 || InstructionD[DATA_WIDTH-1:25] == 7'b111_1000 );
        }
        
        constraint FTypeFunct3 
        {
            if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b001_0000)
            {
                InstructionD[14:12] inside {3'b000,3'b001,3'b010};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b111_0000)
            {
                InstructionD[14:12] inside {3'b000 , 3'b001};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b101_0000) 
            {
                InstructionD[14:12] inside {3'b000,3'b001,3'b010};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b111_1000) 
            {
                InstructionD[14:12] inside {3'b000};
            }
        }

        constraint FTypeRs2 
        {
            if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b010_1100)
            {
                InstructionD[24:20] inside {5'b00000};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b110_0000)
            {
                InstructionD[24:20] inside {5'b00000 , 5'b00001};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b111_0000) 
            {
                InstructionD[24:20] inside {5'b00000};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b110_1000) 
            {
                InstructionD[24:20] inside {5'b00000 , 5'b00001};
            }
            else if((opcode_t'(InstructionD[6:0]) == FLOATING_PT) && InstructionD[DATA_WIDTH-1:25] == 7'b111_1000) 
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
            return $sformatf("The inputs of the transaction are rst = %0d , PCPlus4D = %0d , Opcode = %s , rest of instruction = %0h ,RdW = %s , FlushE = %0d , RegWriteW = %0d , ResultW = %0d,RdFW = %s , FPUOutW = %s , MoveOperationW = %s , FPURegWriteW = %0d and the outputs are Rs1E = %s , Rs2E = %s , Rs1D = %s , Rs2D = %s , RdE = %s , ALUControlE = %s , RD1E = %0d , RD2E = %0d , SignImmE = %0d , PCBranchE = %0d , funct3E = %0b , RegWriteE = %0d , SelectorE = %s , MemWriteE = %0d , BranchE = %0d , ALUSrcE = %0d , CsrOperationE = %s , CsrAccess = %0d , CsrIndexE = %s , PCPlus4E = %0d , EcallE = %0d , EbreakE = %0d , MRetE = %0d , IllegaleInstructionE = %0d ,RdFE = %s , RD1FE = %0d , RD2FE = %0d , FPUControlE = %s , RoundModeE = %s , FPURegWriteE = %0d , MoveOperationE = %s , Rs1FE = %s , Rs2FE = %s ",rst,PCPlus4D,opcode.name,InstructionD[DATA_WIDTH-1:0],RdW.name,FlushE,RegWriteW,ResultW,RdFW.name,FPUOutW,MoveOperationW.name,FPURegWriteW,Rs1E.name,Rs2E.name,Rs1D.name,Rs2D.name,RdE.name,ALUControlE.name,RD1E,RD2E,SignImmE,PCBranchE,funct3E,RegWriteE,SelectorE.name,MemWriteE,BranchE,ALUSrcE,CsrOperationE.name,CsrAccessE,CsrIndexE.name,PCPlus4E,EcallE,EbreakE,MRetE,IllegaleInstructionE,RdFE.name,RD1FE,RD2FE,FPUControlE.name,RoundModeE.name,FPURegWriteE,MoveOperationE.name,Rs1FE.name,Rs2FE.name);
        endfunction: convert2str

        function void post_randomize;
            PCPlus4D = PCPlus4D + 32'h4;
        endfunction: post_randomize


    endclass: decode_item



endpackage:decode_item_pkg