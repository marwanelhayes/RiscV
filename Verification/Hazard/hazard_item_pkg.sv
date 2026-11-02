// =============================================================================
// hazard_item_pkg.sv
// -----------------------------------------------------------------------------
// Hazard unit sequence item package for UVM verification.
// =============================================================================
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
        rand fpr_t RdFM;
        rand fpr_t RdFW;
        rand fpr_t Rs1FE;
        rand fpr_t Rs2FE;
        rand logic FPURegWriteM;
        rand logic FPURegWriteW;
        rand logic FPUValidE;
        rand logic FPUDoneE;
        rand logic ICacheHit;
        rand logic DCacheHit;
        

        logic [2:0] ForwardAE;
        logic [2:0] ForwardBE;
        logic StallD;
        logic StallF;
        logic FlushE;
        logic FlushD;
        logic StallE;
        logic StallM;
        logic StallW;
        logic FlushM;
        logic [1:0] ForwardFloatingAE;
        logic [1:0] ForwardFloatingBE;


        // Contract (PLAN_B §2.3/§3.4): EX raises a redirect (taken branch,
        // jump, trap, MRET) only in a cycle where it advances, so a redirect
        // never coincides with a cache freeze or an FP instruction waiting in
        // EX. x0 is left in the register pools so the x0 guards are exercised.
        constraint RedirectOnlyWhenEAdvances
        {
            (PCSrcE || TrapIsSet) -> (ICacheHit && DCacheHit && !(FPUValidE && !FPUDoneE));
        }

        virtual function string convert2str();
            return $sformatf("Inputs: Rs1E = %s | Rs2E = %s | RdE = %s | Rs1D = %s | Rs2D = %s | RdM = %s | RdW = %s | RegWriteM = %0d | RegWriteW = %0d | SelectorE = %s | PCSrcE = %0d | TrapIsSet = %0d | RdFM = %s | RdFW = %s | Rs1FE = %s | Rs2FE = %s | FPURegWriteM = %0d | FPURegWriteW = %0d | FPUValidE = %0d | FPUDoneE = %0d | ICacheHit = %0b | DCacheHit = %0b
            Outputs: ForwardAE = %0b | ForwardBE = %0b | StallD = %0d | StallF = %0d | StallE = %0d | StallM = %0d | StallW = %0d | FlushE = %0d | FlushD = %0d | FlushM = %0d | ForwardFloatingAE = %0b | ForwardFloatingBE = %0b",
            Rs1E.name(),Rs2E.name(),RdE.name(),Rs1D.name(),Rs2D.name(),RdM.name(),RdW.name(),RegWriteM,RegWriteW,SelectorE.name(),PCSrcE,TrapIsSet,RdFM.name(),RdFW.name(),Rs1FE.name(),Rs2FE.name(),FPURegWriteM,FPURegWriteW,FPUValidE,FPUDoneE,
            ICacheHit,DCacheHit,
            ForwardAE,ForwardBE,StallD,StallF,StallE,StallM,StallW,FlushE,FlushD,FlushM,ForwardFloatingAE,ForwardFloatingBE);
        endfunction: convert2str

        // ── UVM do_compare ───────────────────────────────────────────────
        // Field-by-field equality on the twelve combinational outputs. Used
        // by the scoreboard's in-order comparator via uvm_object::compare.
        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            hazard_item other;
            bit ok;
            bit super_ok;

            if(!$cast(other, rhs))
            begin
                `uvm_fatal("do_compare","rhs is not a hazard_item")
                return 1'b0;
            end

            super_ok  = super.do_compare(rhs, comparer);
            ok = super_ok
                && (this.ForwardAE         === other.ForwardAE)
                && (this.ForwardBE         === other.ForwardBE)
                && (this.ForwardFloatingAE === other.ForwardFloatingAE)
                && (this.ForwardFloatingBE === other.ForwardFloatingBE)
                && (this.StallD            === other.StallD)
                && (this.StallF            === other.StallF)
                && (this.StallE            === other.StallE)
                && (this.StallM            === other.StallM)
                && (this.StallW            === other.StallW)
                && (this.FlushE            === other.FlushE)
                && (this.FlushD            === other.FlushD)
                && (this.FlushM            === other.FlushM);
            if(this.ForwardAE !== other.ForwardAE)
                `uvm_info("ForwardAE Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.ForwardAE, this.ForwardAE), UVM_LOW)
            if(this.ForwardBE !== other.ForwardBE)
                `uvm_info("ForwardBE Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.ForwardBE, this.ForwardBE), UVM_LOW)
            if(this.ForwardFloatingAE !== other.ForwardFloatingAE)
                `uvm_info("ForwardFloatingAE Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.ForwardFloatingAE, this.ForwardFloatingAE), UVM_LOW)
            if(this.ForwardFloatingBE !== other.ForwardFloatingBE)
                `uvm_info("ForwardFloatingBE Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.ForwardFloatingBE, this.ForwardFloatingBE), UVM_LOW)
            if(this.StallD !== other.StallD)
                `uvm_info("StallD Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.StallD, this.StallD), UVM_LOW)
            if(this.StallF !== other.StallF)
                `uvm_info("StallF Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.StallF, this.StallF), UVM_LOW)
            if(this.FlushE !== other.FlushE)
                `uvm_info("FlushE Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.FlushE, this.FlushE), UVM_LOW)
            if(this.FlushD !== other.FlushD)
                `uvm_info("FlushD Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.FlushD, this.FlushD), UVM_LOW)
            if(this.StallE !== other.StallE)
                `uvm_info("StallE Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.StallE, this.StallE), UVM_LOW)
            if(this.StallM !== other.StallM)
                `uvm_info("StallM Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.StallM, this.StallM), UVM_LOW)
            if(this.StallW !== other.StallW)
                `uvm_info("StallW Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.StallW, this.StallW), UVM_LOW)
            if(this.FlushM !== other.FlushM)
                `uvm_info("FlushM Mismatch",$sformatf("Expected: %0h, Actual: %0h", other.FlushM, this.FlushM), UVM_LOW)
            return ok;
        endfunction:do_compare

        // ── UVM do_copy ──────────────────────────────────────────────────
        virtual function void do_copy (uvm_object rhs);
            hazard_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("do_copy","rhs is not a hazard_item")
                return;
            end
            
            super.do_copy(rhs);
            this.Rs1E = other.Rs1E;
            this.Rs2E = other.Rs2E;
            this.RdE = other.RdE;
            this.Rs1D = other.Rs1D;
            this.Rs2D = other.Rs2D;
            this.RdM = other.RdM;
            this.RdW = other.RdW;
            this.RegWriteM = other.RegWriteM;
            this.RegWriteW = other.RegWriteW;
            this.SelectorE = other.SelectorE;
            this.PCSrcE = other.PCSrcE;
            this.TrapIsSet = other.TrapIsSet;
            this.RdFM = other.RdFM;
            this.RdFW = other.RdFW;
            this.Rs1FE = other.Rs1FE;
            this.Rs2FE = other.Rs2FE;
            this.FPURegWriteM = other.FPURegWriteM;
            this.FPURegWriteW = other.FPURegWriteW;
            this.FPUValidE = other.FPUValidE;
            this.FPUDoneE = other.FPUDoneE;
            this.ICacheHit = other.ICacheHit;
            this.DCacheHit = other.DCacheHit;

            this.ForwardAE = other.ForwardAE;
            this.ForwardBE = other.ForwardBE;
            this.StallD = other.StallD;
            this.StallF = other.StallF;
            this.FlushE = other.FlushE;
            this.FlushD = other.FlushD;
            this.StallE = other.StallE;
            this.StallM = other.StallM;
            this.StallW = other.StallW;
            this.FlushM = other.FlushM;
            this.ForwardFloatingAE = other.ForwardFloatingAE;
            this.ForwardFloatingBE = other.ForwardFloatingBE;
        endfunction:do_copy

        // ── UVM do_copy ──────────────────────────────────────────────────
        virtual function void copy_inputs (uvm_object rhs);
            hazard_item other;
            if(!$cast(other, rhs)) begin
                `uvm_fatal("do_copy","rhs is not a hazard_item")
                return;
            end
            
            this.Rs1E = other.Rs1E;
            this.Rs2E = other.Rs2E;
            this.RdE = other.RdE;
            this.Rs1D = other.Rs1D;
            this.Rs2D = other.Rs2D;
            this.RdM = other.RdM;
            this.RdW = other.RdW;
            this.RegWriteM = other.RegWriteM;
            this.RegWriteW = other.RegWriteW;
            this.SelectorE = other.SelectorE;
            this.PCSrcE = other.PCSrcE;
            this.TrapIsSet = other.TrapIsSet;
            this.RdFM = other.RdFM;
            this.RdFW = other.RdFW;
            this.Rs1FE = other.Rs1FE;
            this.Rs2FE = other.Rs2FE;
            this.FPURegWriteM = other.FPURegWriteM;
            this.FPURegWriteW = other.FPURegWriteW;
            this.FPUValidE = other.FPUValidE;
            this.FPUDoneE = other.FPUDoneE;
            this.ICacheHit = other.ICacheHit;
            this.DCacheHit = other.DCacheHit;
        endfunction:copy_inputs


    endclass: hazard_item



endpackage:hazard_item_pkg
