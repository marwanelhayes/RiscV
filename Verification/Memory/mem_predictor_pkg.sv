// =============================================================================
// mem_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the Memory stage.
//
// DUT decoupling:
//   - The *W outputs are registered in the MEM/WB pipeline register
//     (always_ff) - shadow them and use emit-before-update so the expected
//     transaction lines up with the registered DUT outputs the monitor
//     sampled this cycle.
//   - Asynchronous active-low rst forces *W to reset defaults immediately, so
//     when t.rst == 0 the shadow + reference memory are flushed and reset
//     defaults are emitted in the SAME cycle (the only "update before emit").
//
// Single-cycle golden:
//   The load/store path is modelled by a single-cycle reference memory[]. The
//   real cache + AXI + data_memory slave only have to MATCH this golden at the
//   end of the path (the AXI stream itself is checked by AXI_Assertions, not
//   here). On a cache miss (CacheHitM == 0) the pipeline stalls: the *M inputs
//   are held by the driver and the shadow freezes here, so the store does not
//   commit and *W hold their previous values until the refill completes.
//
// MCOW (Manual Copy On Write):
//   A single persistent expected item (exp) is reused every cycle, stamped
//   with the matching inputs (copy_inputs), and a clone (exp_clone) is
//   published so the scoreboard FIFO never aliases the mutating exp object.
// =============================================================================
package mem_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_item_pkg::*;

    class mem_predictor extends uvm_subscriber #(mem_item);

        `uvm_component_utils(mem_predictor)

        function new (string name = "mem_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(mem_item) exp_port;
        mem_item exp, exp_clone, shadow_inputs;

        localparam int DEPTH = (2**(FINAL_ADDR_WIDTH-2));

        localparam int DATA_BYTES  = FINAL_DATA_WIDTH / 8; //4 for 32-bit data
        localparam int SETS        = CACHE_TOTAL_LINES / CACHE_WAY; // 256
        localparam int LINE_BYTES  = CACHE_LINE_WORDS * DATA_BYTES; // 16
        localparam int TRANSFER_SIZE = $clog2(DATA_BYTES); // AXI size encoding (0=1B, 1=2B, 2=4B, ...)

        localparam int BYTE_OFF_W  = (DATA_BYTES  > 1)  ? $clog2(DATA_BYTES)  : 0; //2
        localparam int OFF_W       = (LINE_BYTES  > 1)  ? $clog2(LINE_BYTES)  : 0; //4
        localparam int IDX_W_RAW   = (SETS        > 1)  ? $clog2(SETS)        : 0; //5
        localparam int IDX_W       = (IDX_W_RAW   > 0)  ? IDX_W_RAW           : 1; //5
        localparam int WAY_W       = (CACHE_WAY         > 1)  ? $clog2(CACHE_WAY)         : 1; //1
        localparam int WORD_W_RAW  = (CACHE_LINE_WORDS  > 1)  ? $clog2(CACHE_LINE_WORDS)  : 0; //2
        localparam int WORD_W      = (WORD_W_RAW  > 0)  ? WORD_W_RAW          : 1; //2
        localparam int TAG_W       = FINAL_ADDR_WIDTH - OFF_W - IDX_W_RAW; //1

        // Single-cycle reference data memory. Inits to 0 to match the
        // data_memory AXI slave (which clears its array at time 0).
        logic signed [FINAL_DATA_WIDTH-1:0] memory [DEPTH];
        logic signed [FINAL_DATA_WIDTH-1:0] cache [SETS][CACHE_WAY][CACHE_LINE_WORDS];
        logic cache_valid [SETS][CACHE_WAY];
        logic [TAG_W-1:0] cache_tag [SETS][CACHE_WAY];
        logic [WAY_W-1:0] cache_victim [SETS];
        logic [3:0] lru_counter [SETS][CACHE_WAY];
        logic cache_dirty [SETS][CACHE_WAY];
        logic [CACHE_WAY-1:0] cache_hit_array;
        logic [WAY_W-1:0] lru_way;
        logic cache_hit;
        logic [IDX_W-1:0] CpuIdx;
        logic [TAG_W-1:0] CpuTag;
        logic [OFF_W-1:0] CpuOffset;
        logic [FINAL_ADDR_WIDTH-1:0] CPUAddr;
        logic [FINAL_ADDR_WIDTH-3:0] OldTagAddr;
        logic [FINAL_ADDR_WIDTH-3:0] AddressAlign;

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
            reset_shadow();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            reset_shadow();
            foreach(memory[i])
                memory[i] = '0;
        endtask:reset_phase

        // Mirror the memory_stage MEM/WB reset block + clear reference memory.
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
            
            foreach(cache[i,j,k])
                cache[i][j][k] = '0;
            foreach(cache_valid[i,j])
                cache_valid[i][j] = 1'b0;
            foreach(cache_tag[i,j])
                cache_tag[i][j] = '0;
            foreach(cache_victim[i])                
                cache_victim[i] = '0;
            foreach(cache_dirty[i,j])
                cache_dirty[i][j] = 1'b0;
            
            cache_hit = 1'b0;
        endfunction:reset_shadow

        function void cache_predict (mem_item t);
            CPUAddr = t.ALUOutM[FINAL_ADDR_WIDTH-1:0];
            cache_hit_array = '0;
            cache_hit = 1'b0;
            CpuOffset = CPUAddr[OFF_W-1:0];
            AddressAlign = 'b0;
            AddressAlign = {t.ALUOutM[FINAL_ADDR_WIDTH-1:OFF_W], {(OFF_W - 2){1'b0}}}; // Align to word boundary for memory array access
            
            if(CACHE_WAY == CACHE_TOTAL_LINES)
            begin
                CpuIdx = '0;
                CpuTag = CPUAddr[FINAL_ADDR_WIDTH-1:OFF_W];
            end
            else
            begin
                CpuIdx = CPUAddr[OFF_W+IDX_W-1:OFF_W];
                CpuTag = CPUAddr[FINAL_ADDR_WIDTH-1:OFF_W+IDX_W];
            end
            
            q_ReadDataW = 0;
            
            if(CACHE_WAY == 1)
            begin:direct_mapped
                if(t.MemWriteM && t.CacheHitM)
                begin:write_scenario
                    q_ReadDataW = 0;
                    cache_hit = 1'b0;
                    OldTagAddr = {cache_tag[CpuIdx][0], CpuIdx, {2{1'b0}}};
                    if((cache_valid[CpuIdx][0] == 1'b1) && (cache_tag[CpuIdx][0] == CpuTag))
                    begin
                        cache_hit = 1'b1;
                    end
                    
                    if(cache_hit == 1'b1)
                    begin
                        cache_dirty[CpuIdx][0] = 1'b1;
                        cache[CpuIdx][0][CpuOffset[OFF_W-1:2]] = t.WriteDataM;
                        q_ReadDataW = cache[CpuIdx][0][CpuOffset[OFF_W-1:2]];
                    end
                    else
                    begin 
                        if((cache_valid[CpuIdx][0] == 1'b1) && (cache_dirty[CpuIdx][0] == 1'b1))
                        begin
                            for(int word = 0; word < CACHE_LINE_WORDS; word++)
                            begin
                                memory[OldTagAddr + word] = cache[CpuIdx][0][word];
                            end
                        end
                        
                        for(int word = 0; word < CACHE_LINE_WORDS; word++)
                        begin
                            cache[CpuIdx][0][word] = memory[AddressAlign + word];
                        end
                        cache[CpuIdx][0][CpuOffset[OFF_W-1:2]] = t.WriteDataM;
                        q_ReadDataW = cache[CpuIdx][0][CpuOffset[OFF_W-1:2]];
                        cache_valid[CpuIdx][0] = 1'b1;
                        cache_dirty[CpuIdx][0] = 1'b1;
                        cache_tag[CpuIdx][0] = CpuTag;
                    end
                end:write_scenario
                else if(t.CacheHitM)
                begin:read_scenario
                    OldTagAddr = {cache_tag[CpuIdx][0], CpuIdx, {2{1'b0}}};
                    cache_hit = 1'b0;
                    if((cache_valid[CpuIdx][0] == 1'b1) && (cache_tag[CpuIdx][0] == CpuTag))
                    begin
                        cache_hit = 1'b1;
                    end
                    
                    if(!cache_hit)
                    begin
                        if((cache_valid[CpuIdx][0] == 1'b1) && (cache_dirty[CpuIdx][0] == 1'b1))
                        begin
                            for(int word = 0; word < CACHE_LINE_WORDS; word++)
                            begin
                                memory[OldTagAddr + word] = cache[CpuIdx][0][word];
                            end
                        end
                        cache_valid[CpuIdx][0] = 1'b1;
                        cache_dirty[CpuIdx][0] = 1'b0;
                        cache_tag[CpuIdx][0] = CpuTag;
                        for(int word = 0; word < CACHE_LINE_WORDS; word++)
                        begin
                            cache[CpuIdx][0][word] = memory[AddressAlign + word];
                        end
                        q_ReadDataW = cache[CpuIdx][0][CpuOffset[OFF_W-1:2]];
                    end
                    else
                    begin
                        q_ReadDataW = cache[CpuIdx][0][CpuOffset[OFF_W-1:2]];
                    end
                end:read_scenario
            end:direct_mapped
            else
            begin:set_associative
                // ── Hit detection across all ways ────────────────────────────
                foreach(cache_hit_array[i])
                    cache_hit_array[i] = 1'b0;
                cache_hit = 1'b0;
                for(int way = 0; way < CACHE_WAY; way++)
                begin
                    if(cache_valid[CpuIdx][way] && (cache_tag[CpuIdx][way] == CpuTag))
                    begin
                        cache_hit_array[way] = 1'b1;
                        cache_hit = 1'b1;
                    end
                end

                // ── Victim selection (mirror cache.sv): default to the LRU way,
                //    but any invalid way takes priority (lowest index wins). The
                //    lru_way loop reproduces the DUT's last-two-way comparison.
                lru_way = '0;
                for(int way = 1; way < CACHE_WAY; way++)
                begin
                    if(lru_counter[CpuIdx][way] < lru_counter[CpuIdx][lru_way])
                        lru_way = WAY_W'(way);
                end
                cache_victim[CpuIdx] = lru_way;
                for(int way = CACHE_WAY - 1; way >= 0; way--)
                begin
                    if(!cache_valid[CpuIdx][way])
                        cache_victim[CpuIdx] = WAY_W'(way);
                end

                // Word-base address of the victim line (for write-back) and of
                // the requested line (refill uses AddressAlign) - arithmetic
                // addressing, the same scheme the direct-mapped path uses. When
                // fully associative (WAY == TOTAL_LINES) there is no index field.
                if(CACHE_WAY == CACHE_TOTAL_LINES)
                    OldTagAddr = {cache_tag[CpuIdx][cache_victim[CpuIdx]], {(OFF_W-2){1'b0}}};
                else
                    OldTagAddr = {cache_tag[CpuIdx][cache_victim[CpuIdx]], CpuIdx, {(OFF_W-2){1'b0}}};

                // Only present hit data on a serviced cycle. During a masked
                // hit (line present but the FSM is busy, CacheHitM == 0) the DUT
                // drives ReadDataM = 0, so the model must too - mirrors the
                // direct-mapped path and cache.sv's CacheHit-gated read mux.
                q_ReadDataW = 0;
                if(cache_hit && t.CacheHitM)
                begin
                    for(int way = 0; way < CACHE_WAY; way++)
                        if(cache_hit_array[way])
                            q_ReadDataW = cache[CpuIdx][way][CpuOffset[OFF_W-1:2]];
                end

                if(t.MemWriteM && t.CacheHitM)
                begin:write_way_scenario
                    if(cache_hit)
                    begin:write_hit
                        for(int way = 0; way < CACHE_WAY; way++)
                        begin
                            if(cache_hit_array[way])
                            begin
                                cache_dirty[CpuIdx][way] = 1'b1;
                                cache[CpuIdx][way][CpuOffset[OFF_W-1:2]] = t.WriteDataM;
                                q_ReadDataW = cache[CpuIdx][way][CpuOffset[OFF_W-1:2]];
                            end
                        end
                    end:write_hit
                    else
                    begin:write_allocate
                        if(cache_valid[CpuIdx][cache_victim[CpuIdx]] && cache_dirty[CpuIdx][cache_victim[CpuIdx]])
                            for(int word = 0; word < CACHE_LINE_WORDS; word++)
                                memory[OldTagAddr + word] = cache[CpuIdx][cache_victim[CpuIdx]][word];
                        for(int word = 0; word < CACHE_LINE_WORDS; word++)
                            cache[CpuIdx][cache_victim[CpuIdx]][word] = memory[AddressAlign + word];
                        cache[CpuIdx][cache_victim[CpuIdx]][CpuOffset[OFF_W-1:2]] = t.WriteDataM;
                        cache_valid[CpuIdx][cache_victim[CpuIdx]] = 1'b1;
                        cache_dirty[CpuIdx][cache_victim[CpuIdx]] = 1'b1;
                        cache_tag[CpuIdx][cache_victim[CpuIdx]]   = CpuTag;
                        q_ReadDataW = cache[CpuIdx][cache_victim[CpuIdx]][CpuOffset[OFF_W-1:2]];
                    end:write_allocate
                end:write_way_scenario
                else if(t.CacheHitM)
                begin:read_way_scenario
                    if(!cache_hit)
                    begin:read_allocate
                        if(cache_valid[CpuIdx][cache_victim[CpuIdx]] && cache_dirty[CpuIdx][cache_victim[CpuIdx]])
                            for(int word = 0; word < CACHE_LINE_WORDS; word++)
                                memory[OldTagAddr + word] = cache[CpuIdx][cache_victim[CpuIdx]][word];
                        for(int word = 0; word < CACHE_LINE_WORDS; word++)
                            cache[CpuIdx][cache_victim[CpuIdx]][word] = memory[AddressAlign + word];
                        cache_valid[CpuIdx][cache_victim[CpuIdx]] = 1'b1;
                        cache_dirty[CpuIdx][cache_victim[CpuIdx]] = 1'b0;
                        cache_tag[CpuIdx][cache_victim[CpuIdx]]   = CpuTag;
                        q_ReadDataW = cache[CpuIdx][cache_victim[CpuIdx]][CpuOffset[OFF_W-1:2]];
                    end:read_allocate
                end:read_way_scenario

                // ── LRU counter update (mirror cache.sv): on a serviced access
                //    increment the hit way and decrement every other way, both
                //    saturating. Performed after victim selection so this access
                //    sees the pre-update counters, like the DUT's registered
                //    lru_way. No counter is poked on allocate (matches the DUT).
                if(t.CacheHitM)
                begin
                    for(int way = 0; way < CACHE_WAY; way++)
                    begin
                        if(cache_hit_array[way])
                        begin
                            if(lru_counter[CpuIdx][way] < 4'hF)
                                lru_counter[CpuIdx][way]++;
                        end
                        else
                        begin
                            if(lru_counter[CpuIdx][way] > 0)
                                lru_counter[CpuIdx][way]--;
                        end
                    end
                end
            end:set_associative
        endfunction:cache_predict

        // Compute the NEXT-cycle *W shadow from this cycle's *M inputs. The
        // store commits then the load is read back (the single-cycle golden
        // for the whole cache/AXI path). Called only on a serviced cycle
        // (rst asserted, CacheHitM == 1).
        function void update_shadow (mem_item t);
            // q_ReadDataW = '0;
            // if(t.MemWriteM && t.CacheHitM)
            // begin:ReadWrite_shadow_update
            //     case(load_store_t'(t.funct3M))
            //         W: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]] = t.WriteDataM;
            //         HW:  case(t.ALUOutM[1])
            //             1'b1: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH/2] = t.WriteDataM[FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH/2];
            //             1'b0: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH/2-1:'b0] = t.WriteDataM[FINAL_DATA_WIDTH/2-1:0];
            //         endcase
            //         B:  case(t.ALUOutM[1:0])
            //             2'b11: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))] = t.WriteDataM[FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))];
            //             2'b10: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)] = t.WriteDataM[(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)];
            //             2'b01: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)] = t.WriteDataM[(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)];
            //             2'b00: memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1:'b0] = t.WriteDataM[(FINAL_DATA_WIDTH/4)-1:0];
            //         endcase
            //     endcase
            // end:ReadWrite_shadow_update
            // case(load_store_t'(t.funct3M))
            //     W: q_ReadDataW = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]];
            //     HW:  case(t.ALUOutM[1])
            //             1'b1:   begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)];
            //                         q_ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)] = {FINAL_DATA_WIDTH/2{memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH)-1]}};
            //                     end
            //             1'b0:   begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:'b0];
            //                         q_ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)] = {FINAL_DATA_WIDTH/2{memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1]}};
            //                     end
            //         endcase
            //     HWU: case(t.ALUOutM[1]) //For unsigned  the most significant bits remain zero
            //             1'b1:   begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)];
            //                     end
            //             1'b0:   begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:'b0];
            //                     end
            //         endcase
            //     B:  case(t.ALUOutM[1:0])
            //             2'b11:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))];
            //                         q_ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH)-1]}};
            //                     end
            //             2'b10:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)];
            //                         q_ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*FINAL_DATA_WIDTH/4)-1]}};
            //                     end
            //             2'b01:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)];
            //                         q_ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1]}};
            //                     end
            //             2'b00:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1:'b0];
            //                         q_ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1]}};
            //                     end
            //         endcase
            //     BU:  case(t.ALUOutM[1:0]) //For unsigned the most significant bits remain zero
            //             2'b11:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))];
            //                     end
            //             2'b10:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)];
            //                     end
            //             2'b01:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)];
            //                     end
            //             2'b00:  begin
            //                         q_ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[t.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1:'b0];
            //                     end
            //         endcase
            // endcase
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
            // Async active-low rst clears the registered *W + reference memory
            // immediately, so the reset defaults are emitted THIS cycle.
            if(!t.rst)
                reset_shadow();

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
                exp.memory[i] = memory[i];

            // Stamp the matching cycle's inputs for readable messaging.
            if(!(shadow_inputs == null))
                exp.copy_inputs(shadow_inputs);

            // Clone before publishing so the FIFO never holds the mutating exp.
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("MEM_PRED", "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);

            // Advance the shadow from this cycle's *M inputs, but only on a
            // serviced cycle: not in reset (rst == 1) AND cache hit. On a miss
            // the pipeline stalls - inputs are held and the shadow freezes
            // (the store does not commit, *W hold their previous values).
            if(t.rst)
            begin
                update_shadow(t);
                cache_predict(t);
            end

            if(!$cast(shadow_inputs, t.clone()))
                `uvm_fatal("MEM_PRED", "Failed to clone input item for shadow - check for non-cloneable fields")
        endfunction:write
    endclass:mem_predictor
endpackage:mem_predictor_pkg
