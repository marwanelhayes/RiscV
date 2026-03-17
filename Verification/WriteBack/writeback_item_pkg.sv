package writeback_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class writeback_item extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_utils(writeback_item)

        //Overriding the build in constructor with the child class
        function new (string name = "writeback_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand logic PCSrcE;
        rand logic StallF;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F = 0;
        rand logic [FINAL_ADDR_WIDTH-1:0] PCBranchE;
        rand logic [FINAL_DATA_WIDTH-1:0] ALUOutW;
        rand logic [FINAL_DATA_WIDTH-1:0] ReadDataW;
        rand selector_t SelectorW;
        rand logic [FINAL_DATA_WIDTH-1:0] CsrOutW;
        rand logic [FINAL_ADDR_WIDTH-1:0] PCPlus4W;
        rand logic TrapIsSet;
        rand logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC;

        logic [FINAL_DATA_WIDTH-1:0] ResultW;
        logic [FINAL_ADDR_WIDTH-1:0] PCF;
        


        //Insert random resets at random times
        constraint LowResetProb 
        {
            rst dist {0:=5,1:=200};
        }


        

        virtual function string convert2str();
            return $sformatf("The inputs of the transaction are rst = %0d , PCSrcE = %0d , StallF = %0d , PCPlus4F = %0h , PCBranchE = %0h , ALUOutW = %0h , ReadDataW = %0h , SelectorW = %s , CsrOutW = %0d , PCPlus4W = %0h , TrapIsSet = %0d , CsrOutPC = %0h",rst,PCSrcE,StallF,PCPlus4F,PCBranchE,ALUOutW,ReadDataW,SelectorW.name(),CsrOutW,PCPlus4W,TrapIsSet,CsrOutPC);
        endfunction: convert2str

        function void post_randomize;
            PCPlus4F = PCPlus4F + 32'h4;
        endfunction: post_randomize


    endclass: writeback_item



endpackage:writeback_item_pkg
