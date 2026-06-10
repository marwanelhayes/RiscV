// =============================================================================
// fetch_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the fetch stage.
//
// Implements the emit-before-update sequential reference model so its output
// transaction is sampled in lockstep with the registered DUT IF/ID outputs.
//
// Flow:
//   1. Listen on the monitor analysis port (subscriber pattern).
//   2. Publish the previous-cycle register contents on exp_port (this matches
//      what the monitor sampled this cycle from the DUT).
//   3. Advance the internal shadow register from the current inputs gated by
//      CacheHitF (cache refill freezes IF/ID just like the design).
//
// The instruction memory image is loaded from INSTR_MEM_PATH defined in
// shared_pkg so the reference image stays in sync with the design's ROM.
// =============================================================================
package fetch_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import fetch_item_pkg::*;

    class fetch_predictor extends uvm_subscriber #(fetch_item);

        //Register the class to the factory
        `uvm_component_utils(fetch_predictor)

        //Override the constructor function
        function new (string name = "fetch_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        // Expected-output broadcast port
        uvm_analysis_port #(fetch_item) exp_port;
        fetch_item shadow_inputs,exp_clone ,exp;

        // Reference memory image (loaded from INSTR_MEM_PATH)
        localparam int DEPTH = (2**(FINAL_ADDR_WIDTH-2));
        logic signed [FINAL_DATA_WIDTH-1:0] memory [DEPTH];

        // Shadow IF/ID register (advanced one cycle behind the emit)
        logic [FINAL_ADDR_WIDTH-1:0] q_PCPlus4D;
        logic [FINAL_DATA_WIDTH-1:0] q_InstructionD;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = fetch_item::type_id::create("exp");
            $readmemb(INSTR_MEM_PATH, memory);
            q_PCPlus4D     = '0;
            q_InstructionD = 32'h00_00_00_33;
        endfunction:build_phase

        // Reset the shadow on a fresh reset assertion so post-reset cycles
        // do not inherit stale state.
        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            q_PCPlus4D     = '0;
            q_InstructionD = 32'h00_00_00_33;
        endtask:reset_phase

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (fetch_item t);
            exp.PCPlus4F     = t.PCF + 4;     // combinational, race-free

            // Emit before update for registers
            exp.PCPlus4D     = t.rst ? q_PCPlus4D : 32'h00_00_00_00;
            exp.InstructionD = t.rst ? q_InstructionD : 32'h00_00_00_33;
            
            if(!(shadow_inputs == null))
                exp.copy_inputs(shadow_inputs);

            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("FETCH_PRED", "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);

            // 2) Advance shadow for the next clock edge.
            if(!t.rst)
            begin
                q_PCPlus4D     = '0;
                q_InstructionD = 32'h00_00_00_33;
            end
            else if(t.FlushD)
            begin
                q_PCPlus4D     = '0;
                q_InstructionD = 32'h00_00_00_33;
            end
            else if(!t.StallD)
            begin
                q_InstructionD = memory[t.PCF[FINAL_ADDR_WIDTH-1:2]];
                q_PCPlus4D     = t.PCF + 4;
            end
            if(!$cast(shadow_inputs, t.clone()))
                `uvm_fatal("FETCH_PRED", "Failed to clone input item for shadow - check for non-cloneable fields")
        endfunction:write

    endclass:fetch_predictor


endpackage: fetch_predictor_pkg
