// =============================================================================
// mem_item_pkg.sv
// -----------------------------------------------------------------------------
// Memory stage sequence item package for UVM verification.
// =============================================================================
package mem_item_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;

    class mem_item extends uvm_sequence_item;
        
        //Register the class in the factory
        `uvm_object_utils(mem_item)

        //Overriding the build in constructor with the child class
        function new (string name = "mem_item");
            super.new(name);
        endfunction: new

        localparam int DEPTH = (2**(FINAL_ADDR_WIDTH-2)); // Assuming word-addressable memory

        rand logic rst;
        rand logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM;
        rand logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM;
        rand logic [FINAL_ADDR_WIDTH-1:0] PCPlus4M;
        rand gpr_t RdM;
        rand logic [2:0] funct3M;
        rand logic RegWriteM;
        rand logic [FINAL_DATA_WIDTH-1:0] CsrOutM;
        rand selector_t SelectorM;
        rand logic MemWriteM;
        rand fpr_t RdFM;
        rand logic OverflowM;
        rand logic UnderflowM;
        rand logic NaNM;
        rand logic InfM;
        rand logic ZeroM;
        rand logic InvalidDivM;
        rand logic [FINAL_DATA_WIDTH-1:0] FPUOutM;
        rand move_operation_t MoveOperationM;
        rand logic FPURegWriteM;

        // Cache hit response (DUT output). 0 = cache miss, pipeline stalls and
        // the *M inputs are held until the refill completes (CacheHitM == 1).
        logic CacheHitM;

        logic signed [FINAL_DATA_WIDTH-1:0] ReadDataW;
        gpr_t RdW;
        logic RegWriteW;
        selector_t SelectorW;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4W;
        logic [FINAL_DATA_WIDTH-1:0] CsrOutW;
        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutW;
        fpr_t RdFW;
        logic OverflowW;
        logic UnderflowW;
        logic NaNW;
        logic InfW;    
        logic ZeroW;
        logic InvalidDivW;
        logic [FINAL_DATA_WIDTH-1:0] FPUOutW;
        move_operation_t MoveOperationW;
        logic FPURegWriteW;

        logic [FINAL_ADDR_WIDTH-1:0] AddrM; // For predictor visibility only, not an actual item field
        logic signed [FINAL_DATA_WIDTH-1:0] memory [DEPTH]; // For predictor visibility only, not an actual item field


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

        constraint OnlyWord
        {
            load_store_t'(funct3M) == W; // Only allow word accesses for now to simplify
        }

        

        virtual function string convert2str();
            AddrM = ALUOutM[FINAL_ADDR_WIDTH-1:0];
            return $sformatf("Inputs: rst = %0d | CacheHitM = %0d | ALUOutM = %0h | WriteDataM = %0h | RdM = %s | funct3M = %0d | RegWriteM = %0d | SelectorM = %s | MemWriteM = %0d | PCPlus4M = %0h | CsrOutM = %0h | RdFM = %s | OverflowM = %0d | UnderflowM = %0d | NaNM = %0d | InfM = %0d | ZeroM = %0d | InvalidDivM = %0d | FPUOutM = %0h | MoveOperationM = %s | FPURegWriteM = %0d | Addresss %0h
            Outputs: ReadDataW = %0h | RdW = %s | RegWriteW = %0d | SelectorW = %s | PCPlus4W = %0h | CsrOutW = %0h | ALUOutW = %0h | RdFW = %s | OverflowW = %0d | UnderflowW = %0d | NaNW = %0d | InfW = %0d | ZeroW = %0d | InvalidDivW = %0d | FPUOutW = %0h | MoveOperationW = %s | FPURegWriteW = %0d
            The Memory value at the address is %0h",
            rst,CacheHitM,ALUOutM,WriteDataM,RdM.name(),funct3M,RegWriteM,SelectorM.name(),MemWriteM,PCPlus4M,CsrOutM,RdFM.name(),OverflowM,UnderflowM,NaNM,InfM,ZeroM,InvalidDivM,FPUOutM,MoveOperationM.name(),FPURegWriteM,AddrM,
            ReadDataW,RdW.name(),RegWriteW,SelectorW.name(),PCPlus4W,CsrOutW,ALUOutW,RdFW.name(),OverflowW,UnderflowW,NaNW,InfW,ZeroW,InvalidDivW,FPUOutW,MoveOperationW.name(),FPURegWriteW,memory[AddrM[FINAL_ADDR_WIDTH-1:2]]); // Assuming word-addressable memory
        endfunction: convert2str

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            mem_item other;
            bit ok;
            bit super_ok;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a mem_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok
                && (this.ReadDataW     === other.ReadDataW)
                && (this.RdW          === other.RdW)
                && (this.RegWriteW    === other.RegWriteW)
                && (this.SelectorW    === other.SelectorW)
                && (this.PCPlus4W     === other.PCPlus4W)
                && (this.CsrOutW      === other.CsrOutW)
                && (this.ALUOutW      === other.ALUOutW)
                && (this.RdFW         === other.RdFW)
                && (this.OverflowW    === other.OverflowW)
                && (this.UnderflowW   === other.UnderflowW)
                && (this.NaNW         === other.NaNW)
                && (this.InfW         === other.InfW)
                && (this.ZeroW        === other.ZeroW)
                && (this.InvalidDivW  === other.InvalidDivW)
                && (this.FPUOutW      === other.FPUOutW)
                && (this.MoveOperationW === other.MoveOperationW)
                && (this.FPURegWriteW === other.FPURegWriteW);
            if(this.ReadDataW !== other.ReadDataW)
                `uvm_info("ReadDataW Mismatch", $sformatf("Expected: %0h Actual: %0h", other.ReadDataW, this.ReadDataW), UVM_LOW)
            if(this.RdW !== other.RdW)
                `uvm_info("RdW Mismatch", $sformatf("Expected: %s Actual: %s", other.RdW.name(), this.RdW.name()), UVM_LOW)
            if(this.RegWriteW !== other.RegWriteW)
                `uvm_info("RegWriteW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.RegWriteW, this.RegWriteW), UVM_LOW)
            if(this.SelectorW !== other.SelectorW)
                `uvm_info("SelectorW Mismatch", $sformatf("Expected: %s Actual: %s", other.SelectorW.name(), this.SelectorW.name()), UVM_LOW)
            if(this.PCPlus4W !== other.PCPlus4W)
                `uvm_info("PCPlus4W Mismatch", $sformatf("Expected: %0h Actual: %0h", other.PCPlus4W, this.PCPlus4W), UVM_LOW)
            if(this.CsrOutW !== other.CsrOutW)
                `uvm_info("CsrOutW Mismatch", $sformatf("Expected: %0h Actual: %0h", other.CsrOutW, this.CsrOutW), UVM_LOW)
            if(this.ALUOutW !== other.ALUOutW)
                `uvm_info("ALUOutW Mismatch", $sformatf("Expected: %0h Actual: %0h", other.ALUOutW, this.ALUOutW), UVM_LOW)
            if(this.RdFW !== other.RdFW)
                `uvm_info("RdFW Mismatch", $sformatf("Expected: %s Actual: %s", other.RdFW.name(), this.RdFW.name()), UVM_LOW)
            if(this.OverflowW !== other.OverflowW)
                `uvm_info("OverflowW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.OverflowW, this.OverflowW), UVM_LOW)
            if(this.UnderflowW !== other.UnderflowW)
                `uvm_info("UnderflowW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.UnderflowW, this.UnderflowW), UVM_LOW)
            if(this.NaNW !== other.NaNW)
                `uvm_info("NaNW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.NaNW, this.NaNW), UVM_LOW)
            if(this.InfW !== other.InfW)
                `uvm_info("InfW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.InfW, this.InfW), UVM_LOW)
            if(this.ZeroW !== other.ZeroW)
                `uvm_info("ZeroW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.ZeroW, this.ZeroW), UVM_LOW)
            if(this.InvalidDivW !== other.InvalidDivW)
                `uvm_info("InvalidDivW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.InvalidDivW, this.InvalidDivW), UVM_LOW)
            if(this.FPUOutW !== other.FPUOutW)
                `uvm_info("FPUOutW Mismatch", $sformatf("Expected: %0h Actual: %0h", other.FPUOutW, this.FPUOutW), UVM_LOW)
            if(this.MoveOperationW !== other.MoveOperationW)
                `uvm_info("MoveOperationW Mismatch", $sformatf("Expected: %s Actual: %s", other.MoveOperationW.name(), this.MoveOperationW.name()), UVM_LOW)
            if(this.FPURegWriteW !== other.FPURegWriteW)
                `uvm_info("FPURegWriteW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.FPURegWriteW, this.FPURegWriteW), UVM_LOW)
            return ok;
        endfunction:do_compare

        // Full deep copy (used by clone() in the monitor and predictor MCOW).
        // super.do_copy is a no-op here (no field-automation macros), so every
        // field must be copied by hand or clones would come back empty.
        virtual function void do_copy (uvm_object rhs);
            mem_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_copy","rhs is not a mem_item")
                return;
            end
            super.do_copy(rhs);
            // Inputs (*M) + cache response
            this.rst            = other.rst;
            this.CacheHitM      = other.CacheHitM;
            this.ALUOutM        = other.ALUOutM;
            this.WriteDataM     = other.WriteDataM;
            this.PCPlus4M       = other.PCPlus4M;
            this.RdM            = other.RdM;
            this.funct3M        = other.funct3M;
            this.RegWriteM      = other.RegWriteM;
            this.CsrOutM        = other.CsrOutM;
            this.SelectorM      = other.SelectorM;
            this.MemWriteM      = other.MemWriteM;
            this.RdFM           = other.RdFM;
            this.OverflowM      = other.OverflowM;
            this.UnderflowM     = other.UnderflowM;
            this.NaNM           = other.NaNM;
            this.InfM           = other.InfM;
            this.ZeroM          = other.ZeroM;
            this.InvalidDivM    = other.InvalidDivM;
            this.FPUOutM        = other.FPUOutM;
            this.MoveOperationM = other.MoveOperationM;
            this.FPURegWriteM   = other.FPURegWriteM;
            this.AddrM          = other.AddrM;
            // Outputs (*W)
            this.ReadDataW      = other.ReadDataW;
            this.RdW            = other.RdW;
            this.RegWriteW      = other.RegWriteW;
            this.SelectorW      = other.SelectorW;
            this.PCPlus4W       = other.PCPlus4W;
            this.CsrOutW        = other.CsrOutW;
            this.ALUOutW        = other.ALUOutW;
            this.RdFW           = other.RdFW;
            this.OverflowW      = other.OverflowW;
            this.UnderflowW     = other.UnderflowW;
            this.NaNW           = other.NaNW;
            this.InfW           = other.InfW;
            this.ZeroW          = other.ZeroW;
            this.InvalidDivW    = other.InvalidDivW;
            this.FPUOutW        = other.FPUOutW;
            this.MoveOperationW = other.MoveOperationW;
            this.FPURegWriteW   = other.FPURegWriteW;

            foreach(this.memory[i])
                this.memory[i] = other.memory[i];
        endfunction:do_copy

        // Copy only the *M inputs (+ rst / CacheHitM). The predictor stamps the
        // expected item with the matching cycle's inputs for readable messaging.
        virtual function void copy_inputs (uvm_object rhs);
            mem_item other;
            if(!$cast(other, rhs))
            begin
                `uvm_fatal("copy_inputs","rhs is not a mem_item")
                return;
            end
            this.rst            = other.rst;
            this.CacheHitM      = other.CacheHitM;
            this.ALUOutM        = other.ALUOutM;
            this.WriteDataM     = other.WriteDataM;
            this.PCPlus4M       = other.PCPlus4M;
            this.RdM            = other.RdM;
            this.funct3M        = other.funct3M;
            this.RegWriteM      = other.RegWriteM;
            this.CsrOutM        = other.CsrOutM;
            this.SelectorM      = other.SelectorM;
            this.MemWriteM      = other.MemWriteM;
            this.RdFM           = other.RdFM;
            this.OverflowM      = other.OverflowM;
            this.UnderflowM     = other.UnderflowM;
            this.NaNM           = other.NaNM;
            this.InfM           = other.InfM;
            this.ZeroM          = other.ZeroM;
            this.InvalidDivM    = other.InvalidDivM;
            this.FPUOutM        = other.FPUOutM;
            this.MoveOperationM = other.MoveOperationM;
            this.FPURegWriteM   = other.FPURegWriteM;
            this.AddrM          = other.AddrM;
        endfunction:copy_inputs


    endclass: mem_item



endpackage:mem_item_pkg
