// =============================================================================
// cache_sva.sv
// -----------------------------------------------------------------------------
// White-box assertions for cache.sv. This is where replacement / victim / tag
// correctness is verified - NOT in the reference model. The flat predictor
// (mem_flat_predictor_pkg.sv) only checks observable load DATA; these bound
// assertions check the cache's internal invariants directly, the way a
// commercial flow splits "architectural data" from "micro-architectural state".
//
// Bound by module type (fetch_top, mem_top, risc_top):
//   bind cache cache_sva #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
//       .TOTAL_LINES(TOTAL_LINES), .WAY(WAY), .LINE_WORDS(LINE_WORDS)) CacheSva (.*);
//
// A5-A10 are miss/refill timing checks: a miss leaves IDLE the next cycle,
// a hit outside IDLE is only the one-cycle read-through pulse carrying the
// beat that just arrived, the last beat returns to IDLE, refills are line
// aligned. Failures go through uvm_report_error so regress.sh counts them.
//
// Derived geometry params mirror cache.sv exactly, so only the five primary
// params need to be supplied by the bind.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;
module cache_sva #(
    parameter int DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH  = 32,
    parameter int TOTAL_LINES = 32,
    parameter int WAY         = 4,
    parameter int LINE_WORDS  = 4,
    // ── derived (do not override) ────────────────────────────────────────────
    parameter int SETS  = TOTAL_LINES / WAY,
    parameter int OFF_W = $clog2(LINE_WORDS * (DATA_WIDTH/8)),
    parameter int IDX_W = (SETS > 1) ? $clog2(SETS) : 1,
    parameter int WAY_W = (WAY  > 1) ? $clog2(WAY)  : 1,
    parameter int TAG_W = ADDR_WIDTH - OFF_W - ((SETS > 1) ? $clog2(SETS) : 0)
)
(
    input logic                 clk,
    input logic                 rst,
    input logic                 CPUReadEn,
    input logic                 CPUWriteEn,
    input logic                 CacheHit,
    input logic [WAY-1:0]       hit_array,
    input wire logic            valid_reg [SETS][WAY],
    input wire logic [TAG_W-1:0] tags_reg [SETS][WAY],
    input logic [IDX_W-1:0]     CpuIdx,
    input logic [TAG_W-1:0]     CpuTag,
    input logic [WAY_W-1:0]     victim_way,
    input wire logic [WAY_W-1:0] lru_way [SETS],
    input axi_state_t           state,
    input logic [DATA_WIDTH-1:0] CPUReadData,
    input logic [ADDR_WIDTH-1:0] MARAddr,
    input logic                 MARValid,
    input logic [DATA_WIDTH-1:0] MRRData,
    input logic                 MRRValid,
    input logic                 MRReady,
    input logic                 MRRLast,
    input logic                 read_through_hit,
    input logic                 read_through_hit_reg
);

    // Any invalid way available in a set?
    function automatic bit any_invalid(int idx);
        any_invalid = 1'b0;
        for(int i = 0; i < WAY; i++)
            if(!valid_reg[idx][i]) any_invalid = 1'b1;
    endfunction

    // ── A1: at most one way may claim a hit ──────────────────────────────────
    property p_hit_onehot;
        @(posedge clk) disable iff(!rst)
            (CPUReadEn || CPUWriteEn) |-> ($countones(hit_array) <= 1);
    endproperty
    a_hit_onehot: assert property(p_hit_onehot)
        else uvm_report_error("SVA_CACHE", $sformatf("hit_array not one-hot (%b) - aliasing tags", hit_array));
    a_hit_onehot_cover: cover property (p_hit_onehot);

    // ── A2: no two valid ways in any set share a tag (no duplicate lines) ────
    always @(posedge clk)
        if(rst)
            for(int s = 0; s < SETS; s++)
                for(int i = 0; i < WAY; i++)
                    for(int j = i + 1; j < WAY; j++)
                        assert(!(valid_reg[s][i] && valid_reg[s][j] &&
                                 (tags_reg[s][i] == tags_reg[s][j])))
                        else uvm_report_error("SVA_CACHE", $sformatf("duplicate valid tag in set %0d (ways %0d,%0d)", s, i, j));

    // ── A3: a present line on an IDLE access must be reported as a hit ───────
    //     cache.sv gates the hit on state==AXI_IDLE (a hit is intentionally
    //     suppressed while the FSM is busy with another line's refill), so the
    //     qualifier is required - without it this fires on every hit-while-busy.
    property p_idle_hit_matches_tags;
        @(posedge clk) disable iff(!rst)
            ((CPUReadEn || CPUWriteEn) && (state == AXI_IDLE)) |->
                (CacheHit == (|hit_array));
    endproperty
    a_idle_hit_matches_tags: assert property(p_idle_hit_matches_tags)
        else uvm_report_error("SVA_CACHE", "CacheHit does not match hit_array");
    a_idle_hit_matches_tags_cover: cover property (p_idle_hit_matches_tags);

    // ── A4: replacement policy (set-associative only) ────────────────────────
    //     The victim must be an invalid way whenever one exists; if every way
    //     is valid it must be the true LRU way. The LRU order is rebuilt here
    //     independently from observable state only: a way is "used" by a hit
    //     on an idle access, or when its line changes (a refill). Every way is
    //     refilled before a set is full, so no knowledge of the DUT's reset
    //     ordering is needed.
    generate
        if(WAY > 1)
        begin : gen_repl_checks
            int unsigned ref_age   [SETS][WAY];    // 0 = most recently used
            logic        prev_valid [SETS][WAY];
            logic [TAG_W-1:0] prev_tag [SETS][WAY];

            function automatic void ref_touch(int s, int w);
                for(int j = 0; j < WAY; j++)
                    if((j != w) && (ref_age[s][j] < ref_age[s][w]))
                        ref_age[s][j]++;
                ref_age[s][w] = 0;
            endfunction

            // A2 cover: a set holds two valid lines, so the duplicate-tag check
            // above compares real lines (it is vacuous while every set has one)
            always @(posedge clk)
                if(rst)
                    a_no_dup_tag_cover: cover(valid_reg[CpuIdx][0] && valid_reg[CpuIdx][1]);

            function automatic int ref_lru(int s);
                ref_lru = 0;
                for(int j = 1; j < WAY; j++)
                    if(ref_age[s][j] > ref_age[s][ref_lru]) ref_lru = j;
            endfunction

            always @(posedge clk)
            begin
                if(!rst)
                begin
                    foreach(ref_age[s, w]) ref_age[s][w] = w;
                    foreach(prev_valid[s, w]) begin prev_valid[s][w] = 1'b0; prev_tag[s][w] = '0; end
                end
                else
                begin
                    // Refills that completed at the previous edge (already applied
                    // by the DUT), then the miss check, then this edge's hit.
                    foreach(valid_reg[s, w])
                        if(valid_reg[s][w] && (!prev_valid[s][w] || (tags_reg[s][w] != prev_tag[s][w])))
                            ref_touch(s, w);

                    if((state == AXI_IDLE) && (CPUReadEn || CPUWriteEn) && !(|hit_array))
                    begin
                        if(any_invalid(CpuIdx))
                        begin
                            a_victim_invalid: assert(!valid_reg[CpuIdx][victim_way])
                                else uvm_report_error("SVA_CACHE", $sformatf("victim way %0d valid while an invalid way exists (set %0d)",
                                            victim_way, CpuIdx));
                            a_victim_invalid_cover: cover(!valid_reg[CpuIdx][victim_way]);
                        end
                        else
                        begin
                            a_victim_lru: assert(victim_way == ref_lru(CpuIdx))
                                else uvm_report_error("SVA_CACHE", $sformatf("all ways valid but victim %0d != true-LRU way %0d (set %0d)",
                                            victim_way, ref_lru(CpuIdx), CpuIdx));
                            a_victim_lru_cover: cover(victim_way == ref_lru(CpuIdx));
                        end
                    end

                    if((state == AXI_IDLE) && (CPUReadEn || CPUWriteEn) && (|hit_array))
                        for(int w = 0; w < WAY; w++)
                            if(hit_array[w]) ref_touch(CpuIdx, w);

                    foreach(valid_reg[s, w]) begin prev_valid[s][w] = valid_reg[s][w]; prev_tag[s][w] = tags_reg[s][w]; end
                end
            end
        end
    endgenerate

    // ── A5-A10: miss / refill timing ─────────────────────────────────────────
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_miss_starts: assert property ((state == AXI_IDLE) && (CPUReadEn || CPUWriteEn) && !CacheHit |=> state != AXI_IDLE)
        else uvm_report_error("SVA_CACHE", "miss did not start a refill the next cycle");
    a_miss_starts_cover: cover property ((state == AXI_IDLE) && (CPUReadEn || CPUWriteEn) && !CacheHit |=> state != AXI_IDLE);
    a_busy_hit_is_rt: assert property ((CPUReadEn || CPUWriteEn) && CacheHit && (state != AXI_IDLE) |-> read_through_hit_reg)
        else uvm_report_error("SVA_CACHE", "hit reported while busy outside the read-through pulse");
    a_busy_hit_is_rt_cover: cover property ((CPUReadEn || CPUWriteEn) && CacheHit && (state != AXI_IDLE) |-> read_through_hit_reg);
    a_rt_pulse: assert property (read_through_hit_reg |=> !read_through_hit_reg)
        else uvm_report_error("SVA_CACHE", "read-through hit longer than one cycle");
    a_rt_pulse_cover: cover property (read_through_hit_reg |=> !read_through_hit_reg);
    a_rt_data: assert property (read_through_hit && CPUReadEn && !CPUWriteEn |=> read_through_hit_reg && CPUReadData == $past(MRRData))
        else uvm_report_error("SVA_CACHE", "read-through did not return the arriving beat the next cycle");
    a_rt_data_cover: cover property (read_through_hit && CPUReadEn && !CPUWriteEn |=> read_through_hit_reg && CPUReadData == $past(MRRData));
    a_refill_ends: assert property ((state == AXI_RD_DATA) && MRRValid && MRReady && MRRLast |=> state == AXI_IDLE)
        else uvm_report_error("SVA_CACHE", "last refill beat did not return the FSM to IDLE");
    a_refill_ends_cover: cover property ((state == AXI_RD_DATA) && MRRValid && MRReady && MRRLast |=> state == AXI_IDLE);
    a_line_aligned: assert property ($rose(MARValid) |-> MARAddr[OFF_W-1:0] == '0)
        else uvm_report_error("SVA_CACHE", "refill burst address not line aligned");
    a_line_aligned_cover: cover property ($rose(MARValid) |-> MARAddr[OFF_W-1:0] == '0);
    a_known: assert property (!$isunknown({state, CacheHit}))
        else uvm_report_error("SVA_CACHE", "X on state/CacheHit");
    a_known_cover: cover property (!$isunknown({state, CacheHit}));

endmodule
