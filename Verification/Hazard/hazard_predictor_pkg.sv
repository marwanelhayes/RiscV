// =============================================================================
// hazard_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Hazard Unit.
//
// hazard_unit.sv is 100% combinational - every output (ForwardAE, ForwardBE,
// ForwardFloatingAE, ForwardFloatingBE, StallD, StallF, FlushD, FlushE) is
// driven by an always_comb block that is purely a function of the current
// monitored inputs. There is no clock, no reset, and no pipeline register
// inside the module, so there is no need for the emit-before-update shadow
// pattern used in the pipelined-stage predictors (decode, execute, fpu, csr).
//
// Flow:
//   1. Listen on the monitor analysis port (subscriber pattern).
//   2. Recompute every output from t.* combinationally in the SAME cycle.
//   3. Publish the expected transaction on exp_port.
//
// The scoreboard's in-order FIFOs absorb the monitor/predictor arrival skew
// the same way they do for the other stages, so the comparator pattern
// stays consistent across the project.
// =============================================================================
package hazard_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import hazard_item_pkg::*;

    class hazard_predictor extends uvm_subscriber #(hazard_item);

        //Register the class to the factory
        `uvm_component_utils(hazard_predictor)

        //Override the constructor function
        function new (string name = "hazard_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        // Expected-output broadcast port
        uvm_analysis_port #(hazard_item) exp_port;
        hazard_item exp_clone , exp;

        logic LWStall, FPUStall, CacheStall;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = hazard_item::type_id::create("exp");
        endfunction:build_phase

        virtual function void compute(hazard_item t);
            // ── Load-use hazard ──────────────────────────────────────────
            LWStall = 1'b0;
            if(t.SelectorE == MemToReg && ((t.RdE == t.Rs1D) || (t.RdE == t.Rs2D)))
                LWStall = 1'b1;

            // ── FPU busy hazard ──────────────────────────────────────────
            FPUStall = 1'b0;
            if(t.FPUValidE && t.FPUBusyM)
                FPUStall = 1'b1;
            
            CacheStall = 1'b0;
            if((!t.ICacheHit) || (!t.DCacheHit))
                CacheStall = 1'b1;

            // ── GPR operand A forwarding (priority: WB > MEM, int > FP) ──
            exp.ForwardAE = 3'b000;
            if(t.RegWriteW && (t.RdW != zero) && (t.RdW == t.Rs1E) && (t.MoveOperationE != FPUToReg))
                exp.ForwardAE = 3'b001;
            else if(t.RegWriteM && (t.RdM != zero) && (t.RdM == t.Rs1E) && (t.MoveOperationE != FPUToReg))
                exp.ForwardAE = 3'b010;
            else if(t.RegWriteW && (t.RdW != zero) && (t.RdW == t.Rs1E) && (t.MoveOperationE == FPUToReg))
                exp.ForwardAE = 3'b011;
            else if(t.RegWriteM && (t.RdM != zero) && (t.RdM == t.Rs1E) && (t.MoveOperationE == FPUToReg))
                exp.ForwardAE = 3'b100;

            // ── GPR operand B forwarding ─────────────────────────────────
            exp.ForwardBE = 3'b000;
            if(t.RegWriteW && (t.RdW != zero) && (t.RdW == t.Rs2E) && (t.MoveOperationE != FPUToReg))
                exp.ForwardBE = 3'b001;
            else if(t.RegWriteM && (t.RdM != zero) && (t.RdM == t.Rs2E) && (t.MoveOperationE != FPUToReg))
                exp.ForwardBE = 3'b010;
            else if(t.RegWriteW && (t.RdW != zero) && (t.RdW == t.Rs2E) && (t.MoveOperationE == FPUToReg))
                exp.ForwardBE = 3'b011;
            else if(t.RegWriteM && (t.RdM != zero) && (t.RdM == t.Rs2E) && (t.MoveOperationE == FPUToReg))
                exp.ForwardBE = 3'b100;

            // ── FPR operand A forwarding ─────────────────────────────────
            exp.ForwardFloatingAE = 2'b00;
            if(t.FPURegWriteW && (t.RdFW != f0) && (t.RdFW == t.Rs1FE))
                exp.ForwardFloatingAE = 2'b01;
            else if(t.FPURegWriteM && (t.RdFM != f0) && (t.RdFM == t.Rs1FE))
                exp.ForwardFloatingAE = 2'b10;

            // ── FPR operand B forwarding ─────────────────────────────────
            exp.ForwardFloatingBE = 2'b00;
            if(t.FPURegWriteW && (t.RdFW != f0) && (t.RdFW == t.Rs2FE))
                exp.ForwardFloatingBE = 2'b01;
            else if(t.FPURegWriteM && (t.RdFM != f0) && (t.RdFM == t.Rs2FE))
                exp.ForwardFloatingBE = 2'b10;

            // ── Stall / flush generation ─────────────────────────────────
            // NOTE: hazard_unit.sv also ORs (!ICacheHit) and (!DCacheHit) into
            // StallD/StallF, but those signals are not modelled in the current
            // hazard_item / interface. Keeping parity with the scoreboard's
            // original ref_model so behavior is unchanged.
            exp.StallD = LWStall    | FPUStall | CacheStall;
            exp.StallF = LWStall    | FPUStall | CacheStall;
            exp.FlushE = LWStall    | t.PCSrcE | t.TrapIsSet;
            exp.FlushD = t.PCSrcE   | t.TrapIsSet;
        endfunction:compute

        // ── Combinational reference model ────────────────────────────────────
        // Mirrors the six always_comb blocks in hazard_unit.sv. No shadow,
        // no reset hook - every output is a pure function of current inputs.
        virtual function void write (hazard_item t);

            // Copy stimulus side of the transaction so the scoreboard can
            // print the same input context as the monitored item.
            exp.copy_inputs(t);
            compute(t);
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("HAZARD_PRED", "Failed to clone expected item - check for non-cloneable fields or type mismatches")
            else
                exp_port.write(exp_clone);
        endfunction:write

    endclass:hazard_predictor

endpackage:hazard_predictor_pkg
