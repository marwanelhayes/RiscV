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
//   - Loads and stores from the ISA: SB/SH/SW(/SD) write only their bytes,
//     LB/LH/LW(/LD) sign-extend and LBU/LHU(/LWU) zero-extend the addressed
//     bytes of the last values written. ReadDataW is compared for loads only.
//   - All other *W outputs are plain MEM/WB pipeline-register passthroughs of
//     the *M inputs, shadowed with emit-before-update exactly like the DUT.
//   - StallW (any cache miss freezes the pipeline) holds MEM/WB, and the
//     access commits in the cycle MEM advances.
//   - A extension, from Zalrsc/Zaamo: LR loads and registers a reservation;
//     SC stores rs2 and returns 0 iff the reservation is valid for exactly
//     its address (else 1, no store), and always clears it; AMO* return the
//     old value and store f(old, rs2). Each commits once, when MEM advances,
//     however long the DUT holds it in MEM.
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
    import tb_base_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_item_pkg::*;

    class mem_flat_predictor extends base_predictor #(mem_item);

        `uvm_component_utils(mem_flat_predictor)

        function new (string name = "mem_flat_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_item exp, exp_clone, shadow_inputs;

        localparam int DATA_BYTES = FINAL_DATA_WIDTH / 8;
        localparam int BYTE_OFF_W = $clog2(DATA_BYTES);
        localparam int DEPTH      = 2**(FINAL_ADDR_WIDTH - BYTE_OFF_W);
        typedef logic [FINAL_DATA_WIDTH-1:0] x_t;

        // Hierarchical path to the data_memory array for backdoor resync on
        // reset. Parameterised so it can be retargeted via config_db if the TB
        // instance names change.
        string bkdr_path = "mem_top.DataMem.mem";

        // Flat architectural memory image (one entry per XLEN word).
        logic signed [FINAL_DATA_WIDTH-1:0] mem_ref [DEPTH];

        // Track rst to resync once per reset pulse (on the falling edge), not
        // every reset cycle - data_memory is stable for the whole reset.
        logic prev_rst = 1'b1;

        // LR/SC reservation (cleared by reset, like the DUT)
        bit                          res_valid;
        logic [FINAL_DATA_WIDTH-1:0] res_addr;

        // ── MEM/WB pipeline-register shadows (emit-before-update) ────────────
        logic                               q_ValidW;
        logic                               q_LoadW;
        logic signed [FINAL_DATA_WIDTH-1:0] q_ReadDataW;
        gpr_t                               q_RdW;
        logic                               q_RegWriteW;
        selector_t                          q_SelectorW;
        logic [FINAL_DATA_WIDTH-1:0]        q_PCPlus4W;
        logic [FINAL_DATA_WIDTH-1:0]        q_CsrOutW;
        logic signed [FINAL_DATA_WIDTH-1:0] q_ALUOutW;
        fpr_t                               q_RdFW;
        logic                               q_OverflowW;
        logic                               q_UnderflowW;
        logic                               q_NaNW;
        logic                               q_InfW;
        logic                               q_ZeroW;
        logic                               q_InvalidDivW;
        logic [FINAL_FLP_WIDTH-1:0]         q_FPUOutW;
        move_operation_t                    q_MoveOperationW;
        logic                               q_FPURegWriteW;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
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
            res_valid        = 1'b0;
            q_ValidW         = 1'b0;
            q_LoadW          = 1'b0;
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

        // Architectural load/store (ISA semantics). Called when MEM advances.
        function void flat_predict (mem_item t);
            logic [FINAL_ADDR_WIDTH-1:0] byte_addr;
            int unsigned word_addr, off, size;
            x_t v;
            byte_addr = t.ALUOutM[FINAL_ADDR_WIDTH-1:0];
            word_addr = byte_addr >> BYTE_OFF_W;
            off       = byte_addr % DATA_BYTES;
            size      = 1 << t.funct3M[1:0];
            q_LoadW   = t.MemReadM;
            q_ReadDataW = '0;
            if(t.AmoM)
            begin
                atomic_predict(t, word_addr, off, size);
                return;
            end
            if(t.MemWriteM)
                for(int i = 0; i < size; i++)
                    mem_ref[word_addr][8*(off+i) +: 8] = t.WriteDataM[8*i +: 8];
            if(t.MemReadM)
            begin
                v = x_t'(mem_ref[word_addr]) >> (8*off);
                case(load_store_t'(t.funct3M))
                    B:       q_ReadDataW = x_t'(signed'(v[7:0]));
                    HW:      q_ReadDataW = x_t'(signed'(v[15:0]));
                    W:       q_ReadDataW = x_t'(signed'(v[31:0]));
                    BU:      q_ReadDataW = x_t'(v[7:0]);
                    HWU:     q_ReadDataW = x_t'(v[15:0]);
                    WU:      q_ReadDataW = x_t'(v[31:0]);
                    default: q_ReadDataW = v;                   // LD
                endcase
            end
        endfunction:flat_predict

        // LR / SC / AMO* (.W sign-extends the old value into rd)
        function void atomic_predict (mem_item t, int unsigned word_addr, int unsigned off, int unsigned size);
            x_t old, src, nv;
            bit ok;
            old = x_t'(mem_ref[word_addr]) >> (8*off);
            src = t.WriteDataM;
            if(size == 4)
            begin
                old = x_t'(signed'(old[31:0]));
                src = x_t'(signed'(src[31:0]));
            end
            q_LoadW = 1'b1;
            case(t.AmoOpM)
                AMO_LR: begin
                    q_ReadDataW = old;
                    res_valid = 1'b1;
                    res_addr = t.ALUOutM;
                    return;
                end
                AMO_SC: begin
                    ok = res_valid && (res_addr == t.ALUOutM);
                    q_ReadDataW = ok ? '0 : x_t'(1);
                    res_valid = 1'b0;
                    if(!ok) return;
                    nv = src;
                end
                AMO_SWAP: nv = src;
                AMO_ADD:  nv = old + src;
                AMO_XOR:  nv = old ^ src;
                AMO_AND:  nv = old & src;
                AMO_OR:   nv = old | src;
                AMO_MIN:  nv = ($signed(old) < $signed(src)) ? old : src;
                AMO_MAX:  nv = ($signed(old) > $signed(src)) ? old : src;
                AMO_MINU: nv = (size == 4) ? ((old[31:0] < src[31:0]) ? old : src) : ((old < src) ? old : src);
                default:  nv = (size == 4) ? ((old[31:0] > src[31:0]) ? old : src) : ((old > src) ? old : src);
            endcase
            if(t.AmoOpM != AMO_SC)
                q_ReadDataW = old;
            for(int i = 0; i < size; i++)
                mem_ref[word_addr][8*(off+i) +: 8] = nv[8*i +: 8];
        endfunction:atomic_predict

        // Compute the NEXT-cycle *W passthrough shadow from this cycle's *M
        // inputs (identical to the registered MEM/WB passthrough in the DUT).
        function void update_shadow (mem_item t);
            q_ValidW         = t.ValidM;
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
            exp.ValidW         = q_ValidW;
            exp.chk_readdata   = q_LoadW;
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

            // Stamp the matching cycle's inputs for readable messaging.
            if(!(shadow_inputs == null))
                exp.copy_inputs(shadow_inputs);

            // Clone before publishing so the FIFO never holds the mutating exp.
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal(get_type_name(), "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);

            // Advance the model from this cycle's *M inputs when MEM advances.
            if(t.rst && !t.StallW)
            begin
                update_shadow(t);
                flat_predict(t);
            end

            if(!$cast(shadow_inputs, t.clone()))
                `uvm_fatal(get_type_name(), "Failed to clone input item for shadow - check for non-cloneable fields")
        endfunction:write
    endclass:mem_flat_predictor
endpackage:mem_flat_predictor_pkg

// =============================================================================
// Notes
// -----------------------------------------------------------------------------
// - Backdoor path defaults to "mem_top.DataMem.mem"; risc_test sets
//   BKDR_PATH to "risc_top.DataMem.mem". Needs -voptargs=+acc.
// - The model is associativity- and fill-timing-agnostic: it passes for any
//   CACHE_WAY / CACHE_LINE_WORDS. LRU/victim/fill correctness is covered by
//   cache_sva.sv.
// =============================================================================
