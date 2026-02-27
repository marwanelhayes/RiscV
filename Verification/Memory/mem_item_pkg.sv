package mem_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class mem_item #(parameter int DATA_WIDTH = 32,ADDR_WIDTH = 32) extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_param_utils(mem_item #(DATA_WIDTH,ADDR_WIDTH))

        //Overriding the build in constructor with the child class
        function new (string name = "mem_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand logic signed [DATA_WIDTH-1:0] ALUOutM;
        rand logic signed [DATA_WIDTH-1:0] WriteDataM;
        rand logic [ADDR_WIDTH-1:0] PCPlus4M;
        rand gpr_t RdM;
        rand logic [2:0] funct3M;
        rand logic RegWriteM;
        rand logic [DATA_WIDTH-1:0] CsrOutM;
        rand selector_t SelectorM;
        rand logic MemWriteM;
        rand fpr_t RdFM;
        rand logic OverflowM;
        rand logic UnderflowM;
        rand logic NaNM;
        rand logic InfM;
        rand logic ZeroM;
        rand logic InvalidDivM;
        rand logic [DATA_WIDTH-1:0] FPUOutM;
        rand move_operation_t MoveOperationM;
        rand logic FPURegWriteM;

        logic signed [DATA_WIDTH-1:0] ReadDataW;
        gpr_t RdW;
        logic RegWriteW;
        selector_t SelectorW;
        logic [ADDR_WIDTH-1:0] PCPlus4W;
        logic [DATA_WIDTH-1:0] CsrOutW;
        logic signed [DATA_WIDTH-1:0] ALUOutW;
        fpr_t RdFW;
        logic OverflowW;
        logic UnderflowW;
        logic NaNW;
        logic InfW;    
        logic ZeroW;
        logic InvalidDivW;
        logic [DATA_WIDTH-1:0] FPUOutW;
        move_operation_t MoveOperationW;
        logic FPURegWriteW;


        //Insert random resets at random times
        constraint LowResetProb 
        {
            rst dist {0:=5,1:=200};
        }

        //Register destination cannot be zero in write
        constraint WriteRegNotZero
        {
            RegWriteM == 1 -> RdM != zero;
        }


        

        virtual function string convert2str();
            return $sformatf("The inputs of the transaction are rst = %0d , ALUOUTM = %0d , WriteDataM = %0d , RdM = %s , Funct3M = %0d , RegWriteM = %0d , SelectorM = %s , MemWriteM = %0d , PCPlus4M = %0d , CsrOutM = %0d, RdFM = %s , OverflowM = %0d , UnderflowM = %0d , NaNM = %0d , InfM = %0d , ZeroM = %0d , InvalidDivM = %0d , FPUOutM = %0d , MoveOperationM = %s , FPURegWriteM = %0d and the outputs are ReadDataW = %0d , RdW = %s , RegWriteW = %0d  , ALUOutW = %0d , SelectorW = %s , PCPlus4W = %0d , CsrOutW = %0d , RdFW = %s , OverflowW = %0d , UnderflowW = %0d , NaNW = %0d , InfW = %0d , ZeroW = %0d , InvalidDivW = %0d , FPUOutW = %0d , MoveOperationW = %s , FPURegWriteW = %0d",rst,ALUOutM,WriteDataM,RdM,funct3M,RegWriteM,SelectorM.name(),MemWriteM,PCPlus4M,CsrOutM,RdFM.name(),OverflowM,UnderflowM,NaNM,InfM,ZeroM,InvalidDivM,FPUOutM,MoveOperationM.name(),FPURegWriteM,/*Outputs*/ReadDataW,RdW,RegWriteW,ALUOutW,SelectorW.name(),PCPlus4W,CsrOutW,RdFW.name(),OverflowW,UnderflowW,NaNW,InfW,ZeroW,InvalidDivW,FPUOutW,MoveOperationW.name(),FPURegWriteW);
        endfunction: convert2str


    endclass: mem_item



endpackage:mem_item_pkg