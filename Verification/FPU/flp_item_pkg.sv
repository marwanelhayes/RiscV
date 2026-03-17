package flp_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class flp_item extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_utils(flp_item)

        //Overriding the build in constructor with the child class
        function new (string name = "flp_item");
            super.new(name);
        endfunction: new

        rand logic rst;
        rand logic valid;
        rand logic [FINAL_FLP_WIDTH-1:0] InA;
        rand logic [FINAL_FLP_WIDTH-1:0] InB;
        rand round_mode_t round_mode;
        rand fpu_operation_t operation;
        rand fpr_t RdF;
        rand logic RegWrite;
        rand move_operation_t MoveOperation;

        logic busy;
        logic done;
        logic Overflow;
        logic Underflow;
        logic NaN;
        logic Inf;
        logic Zero;
        logic InvalidDiv;
        logic [FINAL_FLP_WIDTH-1:0] Result;
        fpr_t RdFOut;
        logic RegWriteOut;
        move_operation_t MoveOperationOut;

        //Insert random resets at random times
        constraint LowResetProb 
        {
            rst dist {0:=5,1:=1000};
        }

        constraint ValidInputs 
        {
            valid dist {0:=5,1:=1000};
        }

        virtual function string convert2str();
            return $sformatf("The inputs of the transaction are rst = %0d , valid = %0d , InA = %f/%0h , InB = %f/%0h , round_mode = %s , operation = %s , RdF = %s , RegWrite = %0d , MoveOperation = %s",rst, valid, $bitstoshortreal(InA), InA, $bitstoshortreal(InB), InB, round_mode.name(), operation.name(), RdF.name(), RegWrite, MoveOperation.name());
        endfunction: convert2str

        virtual function string getbusystatus();
            return $sformatf("The busy status of the transaction is busy = %0d and done = %0d", busy, done);
        endfunction: getbusystatus

    endclass: flp_item
endpackage:flp_item_pkg
