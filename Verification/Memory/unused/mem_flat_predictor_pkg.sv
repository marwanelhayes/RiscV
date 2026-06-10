// =============================================================================
// mem_flat_predictor_pkg.sv
// -----------------------------------------------------------------------------
// ARCHITECTURAL (flat) reference model for the Memory stage.
//
// Philosophy (how ARM/AMD/Intel actually check a cache):
//   A cache is *transparent* - a correct cache returns the same load DATA as a
//   system with no cache at all. So the golden model is NOT a structural twin
//   of the RTL cache (ways / LRU / fill timing). It is a flat, address-keyed
//   memory with correct read-after-write semantics. Replacement policy, victim
//   selection and fill latency are PERFORMANCE features, not architectural
//   correctness, so they are deliberately absent here and are checked instead
//   by white-box SVA bound into cache.sv (see cache_sva.sv).
//
// What this models:
//   - ReadDataW: last value written to the accessed word (write-back coherent
//     view). A load returns mem_ref[addr]; a store both drives ReadDataW (the
//     cache echoes CPUWriteData on a write) and commits mem_ref[addr].
//   - All other *W outputs are plain MEM/WB pipeline-register passthroughs of
//     the *M inputs, shadowed with emit-before-update exactly like the DUT.
//
// Reset (the one place a flat model needs help):
//   A write-back cache can hold a dirty line whose store has NOT yet reached
//   data_memory. An async reset drops that line WITHOUT a write-back, so the
//   store is lost in the DUT. The flat model cannot know which stores were
//   flushed, so on reset it RESYNCS mem_ref from the real data_memory contents
//   via a UVM HDL backdoor (uvm_hdl_read) - the professional "scoreboard
//   realign on reset". After resync both sides start from the same image.
//
// Drop-in: same ports/emit contract as mem_predictor. To use, swap the env's
//   `mem_predictor` for `mem_flat_predictor` (see integration notes at bottom).
// =============================================================================
package mem_flat_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_item_pkg::*;

    class mem_flat_predictor extends uvm_subscriber #(mem_item);

        `uvm_component_utils(mem_flat_predictor)

        function new (string name = "mem_flat_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(mem_item) exp_port;
        mem_item exp, exp_clone, shadow_inputs;

        localparam int DEPTH = (2**(FINAL_ADDR_WIDTH-2));

        // Hierarchical path to the data_memory array for backdoor resync on
        // reset. Parameterised so it can be retargeted via config_db if the TB
        // instance names change.
        string bkdr_path = "mem_top.DataMem.mem";

        // Flat architectural memory image (word-addressable).
        logic signed [FINAL_DATA_WIDTH-1:0] mem_ref [DEPTH];

        // Track rst to resync once per reset pulse (on the falling edge), not
        // every reset cycle - data_memory is stable for the whole reset.
        logic prev_rst = 1'b1;

        // ── MEM/WB pipeline-register shadows (emit-before-update) ────────────
        logic signed [FINAL_DATA_WIDTH-1:0] q_ReadDataW;
        gpr_t                               q_RdW;
        logic                               q_RegWriteW;
        selector_t                          q_SelectorW;
        logic [FINAL_ADDR_WIDTH-1:0]        q_PCPlus4W;
        logic [FINAL_DATA_WIDTH-1:0]        q_CsrOutW;
        logic signed [FINAL_DATA_WIDTH-1:0] q_ALUOutW;
        fpr_t                               q_RdFW;
        logic                               q_OverflowW;
        logic                               q_UnderflowW;
        logic                               q_NaNW;
        logic                               q_InfW;
        logic                               q_ZeroW;
        logic                               q_InvalidDivW;
        logic [FINAL_DATA_WIDTH-1:0]        q_FPUOutW;
        move_operation_t                    q_MoveOperationW;
        logic                               q_FPURegWriteW;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp      = mem_item::type_id::create("exp");
            void'(uvm_config_db #(string)::get(this,"","BKDR_PATH",bkdr_path));
            reset_shadow();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_shadow();
            foreach(mem_ref[i])
                mem_ref[i] = '0;
        endtask:reset_phase

        // Mirror the memory_stage MEM/WB reset block (output defaults only).
        function void reset_shadow ();
            q_RdW            = zero;
            q_RegWriteW      = 1'b0;
            q_SelectorW      = ALUToReg;
            q_ALUOutW        = '0;
            q_ReadDataW      = '0;
            q_PCPlus4W       = '0;
            q_CsrOutW        = '0;
            q_RdFW           = f0;
            q_OverflowW      = 1'b0;
            q_UnderflowW     = 1'b0;
            q_NaNW           = 1'b0;
            q_InfW           = 1'b0;
            q_ZeroW          = 1'b0;
            q_InvalidDivW    = 1'b0;
            q_FPUOutW        = '0;
            q_MoveOperationW = FPUToFPU;
            q_FPURegWriteW   = 1'b0;
        endfunction:reset_shadow

        // Backdoor realign: rebuild the flat image from the DUT's data_memory,
        // the post-reset source of truth (dirty cache lines were dropped). Uses
        // the UVM HDL backdoor; requires +acc on the data_memory array.
        function void resync_from_memory ();
            logic [FINAL_DATA_WIDTH-1:0] word;
            for(int i = 0; i < DEPTH; i++)
            begin
                if(uvm_hdl_read($sformatf("%s[%0d]", bkdr_path, i), word))
                    mem_ref[i] = word;
            end
        endfunction:resync_from_memory

        // Architectural ReadDataW + store commit. Serviced cycle only.
        function void flat_predict (mem_item t);
            logic [FINAL_ADDR_WIDTH-3:0] word_addr;
            word_addr   = t.ALUOutM[FINAL_ADDR_WIDTH-1:2];
            q_ReadDataW = '0;
            if(t.CacheHitM)
            begin
                if(t.MemWriteM)
                begin
                    // Cache echoes CPUWriteData on a write; commit the store to
                    // the coherent image (word store - matches the DUT cache,
                    // which writes a full word with MWStrb = all-ones).
                    q_ReadDataW        = t.WriteDataM;
                    mem_ref[word_addr] = t.WriteDataM;
                end
                else
                begin
                    q_ReadDataW = mem_ref[word_addr];
                end
            end
            // else: cache miss / stall -> DUT drives ReadDataM = 0 this cycle.
        endfunction:flat_predict

        // Compute the NEXT-cycle *W passthrough shadow from this cycle's *M
        // inputs (identical to the registered MEM/WB passthrough in the DUT).
        function void update_shadow (mem_item t);
            q_RdW            = t.RdM;
            q_RegWriteW      = t.RegWriteM;
            q_SelectorW      = t.SelectorM;
            q_ALUOutW        = t.ALUOutM;
            q_CsrOutW        = t.CsrOutM;
            q_PCPlus4W       = t.PCPlus4M;
            q_RdFW           = t.RdFM;
            q_OverflowW      = t.OverflowM;
            q_UnderflowW     = t.UnderflowM;
            q_NaNW           = t.NaNM;
            q_InfW           = t.InfM;
            q_ZeroW          = t.ZeroM;
            q_InvalidDivW    = t.InvalidDivM;
            q_FPUOutW        = t.FPUOutM;
            q_MoveOperationW = t.MoveOperationM;
            q_FPURegWriteW   = t.FPURegWriteM;
        endfunction:update_shadow

        // ── Emit-before-update reference model ───────────────────────────────
        virtual function void write (mem_item t);
            // Async active-low rst clears the registered *W immediately and the
            // DUT cache loses any dirty lines; realign the flat image to the
            // data_memory ground truth in the SAME cycle.
            if(!t.rst)
            begin
                reset_shadow();
                if(prev_rst)            // falling edge of rst only
                    resync_from_memory();
            end
            prev_rst = t.rst;

            // Emit the *W shadow built last cycle (= what the DUT registered at
            // the most recent posedge and the monitor sampled this cycle).
            exp.ReadDataW      = q_ReadDataW;
            exp.RdW            = q_RdW;
            exp.RegWriteW      = q_RegWriteW;
            exp.SelectorW      = q_SelectorW;
            exp.PCPlus4W       = q_PCPlus4W;
            exp.CsrOutW        = q_CsrOutW;
            exp.ALUOutW        = q_ALUOutW;
            exp.RdFW           = q_RdFW;
            exp.OverflowW      = q_OverflowW;
            exp.UnderflowW     = q_UnderflowW;
            exp.NaNW           = q_NaNW;
            exp.InfW           = q_InfW;
            exp.ZeroW          = q_ZeroW;
            exp.InvalidDivW    = q_InvalidDivW;
            exp.FPUOutW        = q_FPUOutW;
            exp.MoveOperationW = q_MoveOperationW;
            exp.FPURegWriteW   = q_FPURegWriteW;
            foreach(exp.memory[i])
                exp.memory[i] = mem_ref[i];

            // Stamp the matching cycle's inputs for readable messaging.
            if(!(shadow_inputs == null))
                exp.copy_inputs(shadow_inputs);

            // Clone before publishing so the FIFO never holds the mutating exp.
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("MEM_FPRED", "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);

            // Advance the model from this cycle's *M inputs (out of reset).
            if(t.rst)
            begin
                update_shadow(t);
                flat_predict(t);
            end

            if(!$cast(shadow_inputs, t.clone()))
                `uvm_fatal("MEM_FPRED", "Failed to clone input item for shadow - check for non-cloneable fields")
        endfunction:write
    endclass:mem_flat_predictor
endpackage:mem_flat_predictor_pkg

// =============================================================================
// Integration notes
// -----------------------------------------------------------------------------
// 1. compile.do: add after mem_predictor_pkg.sv:
//      vlog -work work -vopt -stats=none ../../Verification/Memory/mem_flat_predictor_pkg.sv
// 2. mem_env_pkg.sv:
//      import mem_flat_predictor_pkg::*;
//      mem_flat_predictor predictor;   // replaces: mem_predictor predictor;
//      predictor = mem_flat_predictor::type_id::create("predictor",this);
//    connect_phase is unchanged (same analysis_export / exp_port).
// 3. Backdoor path defaults to "mem_top.DataMem.mem". Override if needed:
//      uvm_config_db #(string)::set(null,"*","BKDR_PATH","mem_top.DataMem.mem");
//    Requires the data_memory array to be visible (-voptargs=+acc, already used).
// 4. This model is associativity- and fill-timing-agnostic: it passes for any
//    CACHE_WAY / CACHE_LINE_WORDS with no changes. LRU/victim/fill correctness
//    is covered separately by cache_sva.sv.
// =============================================================================
