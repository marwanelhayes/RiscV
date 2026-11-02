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

        rand logic rst;
        rand logic ValidM;
        rand logic MemReadM;
        rand logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM;
        rand logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM;
        rand logic [FINAL_DATA_WIDTH-1:0] PCPlus4M;
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
        logic StallW;

        logic ValidW;
        logic signed [FINAL_DATA_WIDTH-1:0] ReadDataW;
        gpr_t RdW;
        logic RegWriteW;
        selector_t SelectorW;
        logic [FINAL_DATA_WIDTH-1:0] PCPlus4W;
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

        // Compare mask set by the predictor: ReadDataW is only architectural
        // for a load (for any other instruction it is a don't-care).
        bit chk_readdata = 1;


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

        // A bubble has no side effects; a load or store is never both.
        constraint BubbleIsInert
        {
            !ValidM -> (!MemReadM && !MemWriteM && !RegWriteM && !FPURegWriteM);
            !(MemReadM && MemWriteM);
        }

        // Legal access sizes for the XLEN (LWU/LD/SD are RV64 only), and
        // naturally aligned addresses: EX traps a misaligned access, so the
        // MEM stage never sees one.
        constraint LegalAccess
        {
            if(FINAL_DATA_WIDTH == 64)
            {
                MemReadM  -> load_store_t'(funct3M) inside {B, HW, W, D, BU, HWU, WU};
                MemWriteM -> load_store_t'(funct3M) inside {B, HW, W, D};
            }
            else
            {
                MemReadM  -> load_store_t'(funct3M) inside {B, HW, W, BU, HWU};
                MemWriteM -> load_store_t'(funct3M) inside {B, HW, W};
            }
            (MemReadM || MemWriteM) && (funct3M[1:0] == 2'd1) -> ALUOutM[0]   == 1'b0;
            (MemReadM || MemWriteM) && (funct3M[1:0] == 2'd2) -> ALUOutM[1:0] == 2'b00;
            (MemReadM || MemWriteM) && (funct3M[1:0] == 2'd3) -> ALUOutM[2:0] == 3'b000;
            MemReadM dist {0:=1, 1:=1};
        }

        

        virtual function string convert2str();
            return $sformatf({"Inputs: rst=%0d valid=%0d hit=%0d addr=%0h read=%0d write=%0d f3=%0d data=%0h ",
                              "Outputs: valid=%0d read=%0h rd=%s reg_write=%0d"},
                rst, ValidM, CacheHitM, ALUOutM, MemReadM, MemWriteM, funct3M, WriteDataM,
                ValidW, ReadDataW, RdW.name(), RegWriteW);
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
                && (this.ValidW       === other.ValidW)
                && (!other.chk_readdata || (this.ReadDataW === other.ReadDataW))
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
            if(this.ValidW !== other.ValidW)
                `uvm_info("ValidW Mismatch", $sformatf("Expected: %0d Actual: %0d", other.ValidW, this.ValidW), UVM_LOW)
            if(other.chk_readdata && (this.ReadDataW !== other.ReadDataW))
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
            this.ValidM         = other.ValidM;
            this.MemReadM       = other.MemReadM;
            this.StallW         = other.StallW;
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
            // Outputs (*W)
            this.ValidW         = other.ValidW;
            this.chk_readdata   = other.chk_readdata;
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
            this.ValidM         = other.ValidM;
            this.MemReadM       = other.MemReadM;
            this.StallW         = other.StallW;
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
        endfunction:copy_inputs


    endclass: mem_item



endpackage:mem_item_pkg
