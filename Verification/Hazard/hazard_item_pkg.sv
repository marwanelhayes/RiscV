package hazard_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class hazard_item extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_utils(hazard_item)

        //Overriding the build in constructor with the child class
        function new (string name = "hazard_item");
            super.new(name);
        endfunction: new

        rand gpr_t Rs1E;
        rand gpr_t Rs2E;
        rand gpr_t RdE;
        rand gpr_t Rs1D; 
        rand gpr_t Rs2D; 
        rand gpr_t RdM;
        rand gpr_t RdW;
        rand logic RegWriteM;
        rand logic RegWriteW;
        rand selector_t SelectorE;
        rand logic PCSrcE; 
        rand logic TrapIsSet;
        rand move_operation_t MoveOperationE;
        rand fpr_t RdFM;
        rand fpr_t RdFW;
        rand fpr_t Rs1FE;
        rand fpr_t Rs2FE;
        rand logic FPURegWriteM;
        rand logic FPURegWriteW;
        

        logic [2:0] ForwardAE;
        logic [2:0] ForwardBE;
        logic StallD;
        logic StallF;
        logic FlushE;
        logic FlushD;
        logic [1:0] ForwardFloatingAE;
        logic [1:0] ForwardFloatingBE;


        //Insert random resets at random times
        constraint NoZeroReg 
        {
            RdE != zero;
            RdM != zero;
            RdW != zero;
        }


        

        virtual function string convert2str();

            return $sformatf("The inputs of the transaction are Rs1E = %s , Rs2E = %s , RdE = %s , Rs1D = %s , Rs2D = %s , RdM = %s , RdW = %s , RegWriteM = %0d , RegWriteW = %0d , SelectorE = %s , PCSrcE = %0d , TrapIsSet = %0d , MoveOperationE = %s , RdFM = %s , RdFW = %s , Rs1FE = %s , Rs2FE = %s , FPURegWriteM = %0d , FPURegWriteW = %0d , and the outputs are ForwardAE = %0d , ForwardBE = %0d , StallD = %0d , StallF = %0d , FlushE = %0d , FlushD = %0d , ForwardFloatingAE = %0d , ForwardFloatingBE = %0d",
            Rs1E.name(), Rs2E.name(), RdE.name(), Rs1D.name(), Rs2D.name(), RdM.name(), RdW.name(),RegWriteM,RegWriteW,SelectorE.name(),PCSrcE,TrapIsSet, MoveOperationE.name(), RdFM.name(), RdFW.name(), Rs1FE.name(), Rs2FE.name(), FPURegWriteM, FPURegWriteW,
            ForwardAE,ForwardBE,StallD,StallF,FlushE,FlushD,ForwardFloatingAE,ForwardFloatingBE);
        
        endfunction: convert2str


    endclass: hazard_item



endpackage:hazard_item_pkg