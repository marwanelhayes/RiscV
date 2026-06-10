// =============================================================================
// writeback_item_pkg.sv
// -----------------------------------------------------------------------------
// Write-back stage sequence item package for UVM verification.
// =============================================================================
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
            return $sformatf("Inputs: rst = %0d | PCSrcE = %0d | StallF = %0d | PCPlus4F = %0h | PCBranchE = %0h | ALUOutW = %0h | ReadDataW = %0h | SelectorW = %s | CsrOutW = %0h | PCPlus4W = %0h | TrapIsSet = %0d | CsrOutPC = %0h
            Outputs: ResultW = %0h | PCF = %0h",
            rst,PCSrcE,StallF,PCPlus4F,PCBranchE,ALUOutW,ReadDataW,SelectorW.name(),CsrOutW,PCPlus4W,TrapIsSet,CsrOutPC,
            ResultW,PCF);
        endfunction: convert2str

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            writeback_item other;
            bit ok;
            bit super_ok;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a writeback_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok
                && (this.ResultW === other.ResultW)
                && (this.PCF    === other.PCF);

            if(this.ResultW !== other.ResultW)
                `uvm_info("ResultW Mismatch", $sformatf("Expected: %0h Actual: %0h", this.ResultW, other.ResultW), UVM_LOW)
            if(this.PCF !== other.PCF)
                `uvm_info("PCF Mismatch", $sformatf("Expected: %0h Actual: %0h", this.PCF, other.PCF), UVM_LOW)

            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            writeback_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_copy","rhs is not a writeback_item")
                return;
            end
            super.do_copy(rhs);
            this.rst       = other.rst;
            this.PCSrcE    = other.PCSrcE;
            this.StallF    = other.StallF;
            this.PCPlus4F  = other.PCPlus4F;
            this.PCBranchE = other.PCBranchE;
            this.ALUOutW   = other.ALUOutW;
            this.ReadDataW = other.ReadDataW;
            this.SelectorW = other.SelectorW;
            this.CsrOutW   = other.CsrOutW;
            this.PCPlus4W  = other.PCPlus4W;
            this.TrapIsSet = other.TrapIsSet;
            this.CsrOutPC  = other.CsrOutPC;
            
            this.ResultW   = other.ResultW;
            this.PCF       = other.PCF;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            writeback_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("copy_inputs","rhs is not a writeback_item")
                return;
            end
            this.rst       = other.rst;
            this.PCSrcE    = other.PCSrcE;
            this.StallF    = other.StallF;
            this.PCPlus4F  = other.PCPlus4F;
            this.PCBranchE = other.PCBranchE;
            this.ALUOutW   = other.ALUOutW;
            this.ReadDataW = other.ReadDataW;
            this.SelectorW = other.SelectorW;
            this.CsrOutW   = other.CsrOutW;
            this.PCPlus4W  = other.PCPlus4W;
            this.TrapIsSet = other.TrapIsSet;
            this.CsrOutPC  = other.CsrOutPC;
        endfunction:copy_inputs

        function void post_randomize;
            PCPlus4F = PCPlus4F + 32'h4;
        endfunction: post_randomize


    endclass: writeback_item



endpackage:writeback_item_pkg
