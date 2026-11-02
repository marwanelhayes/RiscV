// =============================================================================
// hazard_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Hazard Unit.
//
// hazard_unit.sv is 100% combinational - every output (forward selects,
// StallF/D/E/M/W, FlushD/E/M) is
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

        logic LWStall, FPUStall, CacheStall, Redirect;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = hazard_item::type_id::create("exp");
        endfunction:build_phase

        // ── Spec model (PLAN_B_LINUX §2.3 / §3.4), not a copy of the RTL ──────
        //   - x0 is never a real dependency (reads 0, writes are dropped).
        //   - f0 is a real register and is forwarded like any other FPR.
        //   - Forwarding takes the youngest producer: MEM before WB.
        //   - Any cache miss freezes every stage (F..W).
        //   - An FP instruction holds F/D/E until the FPU is done; M gets a bubble.
        //   - A load-use hazard holds F/D; E gets a bubble (only if E advances).
        //   - A redirect from EX flushes D and E; a trap also squashes the EX
        //     instruction so it never reaches M.
        virtual function void compute(hazard_item t);
            LWStall    = (t.SelectorE == MemToReg) && (t.RdE != zero) && ((t.RdE == t.Rs1D) || (t.RdE == t.Rs2D));
            FPUStall   = t.FPUValidE && !t.FPUDoneE;
            CacheStall = !t.ICacheHit || !t.DCacheHit;
            Redirect   = t.PCSrcE || t.TrapIsSet;

            exp.ForwardAE = gpr_forward(t, t.Rs1E);
            exp.ForwardBE = gpr_forward(t, t.Rs2E);
            exp.ForwardFloatingAE = fpr_forward(t, t.Rs1FE);
            exp.ForwardFloatingBE = fpr_forward(t, t.Rs2FE);

            exp.StallF = CacheStall || FPUStall || LWStall;
            exp.StallD = CacheStall || FPUStall || LWStall;
            exp.StallE = CacheStall || FPUStall;
            exp.StallM = CacheStall;
            exp.StallW = CacheStall;
            exp.FlushD = Redirect;
            exp.FlushE = Redirect || (LWStall && !exp.StallE);
            exp.FlushM = t.TrapIsSet || (FPUStall && !CacheStall);
        endfunction:compute

        // 000 = register file, 010 = MEM result, 001 = WB result.
        function logic [2:0] gpr_forward(hazard_item t, gpr_t rs);
            if (rs == zero)                       return 3'b000;
            if (t.RegWriteM && (t.RdM == rs))     return 3'b010;
            if (t.RegWriteW && (t.RdW == rs))     return 3'b001;
            return 3'b000;
        endfunction:gpr_forward

        // 00 = register file, 10 = MEM result, 01 = WB result.
        function logic [1:0] fpr_forward(hazard_item t, fpr_t rs);
            if (t.FPURegWriteM && (t.RdFM == rs)) return 2'b10;
            if (t.FPURegWriteW && (t.RdFW == rs)) return 2'b01;
            return 2'b00;
        endfunction:fpr_forward

        // ── Combinational reference model ────────────────────────────────────
        // Written from the pipeline-control contract. No shadow,
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
