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
        
        rand logic                          rst;
        rand logic [FINAL_ADDR_WIDTH-1:0]   PCF;
        rand logic                          StallD;
        rand logic                          FlushD;
        rand logic                          StallBit;
        rand logic                          FlushBit;

        logic [FINAL_ADDR_WIDTH-1:0]        PCPlus4D;
        logic [FINAL_DATA_WIDTH-1:0]        InstructionD;
        logic [FINAL_ADDR_WIDTH-1:0]        PCPlus4F;
        logic                               CacheHitF;



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

        constraint FlushProb
        {
            FlushD dist {0:=180,1:=20};
        }

        virtual function string convert2str();
            return $sformatf("Inputs: rst = %0d | PCF = %0h | StallD = %0d | FlushD = %0d  
            Outputs: CacheHitF = %0d | PCPlus4D = %0h | InstructionD = %0h | PCPlus4F = %0h",
            rst,PCF,StallD,FlushD,
            CacheHitF,PCPlus4D,InstructionD,PCPlus4F);
        endfunction: convert2str

        // ── UVM do_compare (Verification Methodology pattern) ────────────────
        // Field-by-field equality check used by the scoreboard's
        // expected.compare(actual) call.
        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            fetch_item other;
            bit ok;
            bit super_ok;
            
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a fetch_item")
                return 1'b0;
            end
            
            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok && (this.PCPlus4D == other.PCPlus4D) && (this.InstructionD == other.InstructionD) && (this.PCPlus4F == other.PCPlus4F);

            if(this.PCPlus4D !== other.PCPlus4D)
                `uvm_info("PCPlus4D Mismatch", $sformatf("Expected: %0h Actual: %0h", this.PCPlus4D, other.PCPlus4D), UVM_LOW)
            if(this.InstructionD !== other.InstructionD)
                `uvm_info("InstructionD Mismatch", $sformatf("Expected: %0h Actual: %0h", this.InstructionD, other.InstructionD), UVM_LOW)
            if(this.PCPlus4F !== other.PCPlus4F)
                `uvm_info("PCPlus4F Mismatch", $sformatf("Expected: %0h Actual: %0h", this.PCPlus4F, other.PCPlus4F), UVM_LOW)
            
            return ok;
        endfunction:do_compare

        virtual function void do_copy (uvm_object rhs);
            fetch_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_copy","rhs is not a fetch_item")
                return;
            end
            super.do_copy(rhs);
            this.rst = other.rst;
            this.PCF = other.PCF;
            this.StallD = other.StallD;
            this.FlushD = other.FlushD;


            this.CacheHitF = other.CacheHitF;
            this.PCPlus4D = other.PCPlus4D;
            this.InstructionD = other.InstructionD;
            this.PCPlus4F = other.PCPlus4F;
        endfunction:do_copy

        virtual function void copy_inputs (uvm_object rhs);
            fetch_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("copy_inputs","rhs is not a fetch_item")
                return;
            end
            this.rst = other.rst;
            this.PCF = other.PCF;
            this.StallD = other.StallD;
            this.FlushD = other.FlushD;
        endfunction:copy_inputs


    endclass: fetch_item



endpackage:fetch_item_pkg
