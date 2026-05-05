// =============================================================================
// fetch_item_pkg.sv
// -----------------------------------------------------------------------------
// Fetch stage sequence item package for UVM verification.
// =============================================================================
package fetch_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class fetch_item extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_utils(fetch_item)

        //Overriding the build in constructor with the child class
        function new (string name = "fetch_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand logic [FINAL_ADDR_WIDTH-1:0] PCF;
        rand logic StallD;
        rand logic FlushD;

        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D;
        logic [FINAL_DATA_WIDTH-1:0] InstructionD;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F;
        


        //Insert random resets at random times
        constraint LowResetProb 
        {
            rst dist {0:=5,1:=200};
        }

        //Register destination cannot be zero in write
        constraint ProgramCounter
        {
            PCF[1:0] == 2'b00;
        }


        

        virtual function string convert2str();
            return $sformatf("The inputs of the transaction are rst = %0d , PCF = %0d , StallD = %0d , FlushD = %0d",rst,PCF,StallD,FlushD);
        endfunction: convert2str


    endclass: fetch_item



endpackage:fetch_item_pkg
