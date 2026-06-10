// =============================================================================
// cache_sva.sv
// -----------------------------------------------------------------------------
// White-box assertions for cache.sv. This is where replacement / victim / tag
// correctness is verified - NOT in the reference model. The flat predictor
// (mem_flat_predictor_pkg.sv) only checks observable load DATA; these bound
// assertions check the cache's internal invariants directly, the way a
// commercial flow splits "architectural data" from "micro-architectural state".
//
// Bind it to the cache instance, e.g. in mem_top:
//   bind cache cache_sva #(
//       .DATA_WIDTH (FINAL_DATA_WIDTH),
//       .ADDR_WIDTH (FINAL_ADDR_WIDTH),
//       .TOTAL_LINES(CACHE_TOTAL_LINES),
//       .WAY        (CACHE_WAY),
//       .LINE_WORDS (CACHE_LINE_WORDS)
//   ) cache_assertions (
//       .clk(clk), .rst(rst),
//       .CPUReadEn(CPUReadEn), .CPUWriteEn(CPUWriteEn), .CacheHit(CacheHit),
//       .hit_array(hit_array), .valid_reg(valid_reg), .tags_reg(tags_reg),
//       .CpuIdx(CpuIdx), .CpuTag(CpuTag), .victim_way(victim_way),
//       .lru_way(lru_way)
//   );
//
// Derived geometry params mirror cache.sv exactly, so only the five primary
// params need to be supplied by the bind.
// =============================================================================
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
    input logic                 valid_reg [SETS][WAY],
    input logic [TAG_W-1:0]     tags_reg  [SETS][WAY],
    input logic [IDX_W-1:0]     CpuIdx,
    input logic [TAG_W-1:0]     CpuTag,
    input logic [WAY_W-1:0]     victim_way,
    input logic [WAY_W-1:0]     lru_way [SETS],
    input axi_state_t           state
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
        else $error("cache_sva: hit_array not one-hot (%b) - aliasing tags", hit_array);

    // ── A2: no two valid ways in any set share a tag (no duplicate lines) ────
    always @(posedge clk)
        if(rst)
            for(int s = 0; s < SETS; s++)
                for(int i = 0; i < WAY; i++)
                    for(int j = i + 1; j < WAY; j++)
                        assert(!(valid_reg[s][i] && valid_reg[s][j] &&
                                 (tags_reg[s][i] == tags_reg[s][j])))
                        else $error("cache_sva: duplicate valid tag in set %0d (ways %0d,%0d)", s, i, j);

    // ── A3: a present line on an IDLE access must be reported as a hit ───────
    //     cache.sv gates the hit on state==AXI_IDLE (a hit is intentionally
    //     suppressed while the FSM is busy with another line's refill), so the
    //     qualifier is required - without it this fires on every hit-while-busy.
    property p_present_implies_hit;
        @(posedge clk) disable iff(!rst)
            ((CPUReadEn || CPUWriteEn) && (|hit_array) && (state == AXI_IDLE)) |-> CacheHit;
    endproperty
    a_present_implies_hit: assert property(p_present_implies_hit)
        else $error("cache_sva: |hit_array but CacheHit deasserted");

    // ── A4: replacement policy (set-associative only) ────────────────────────
    //     The victim must be an invalid way whenever one exists; if every way
    //     is valid the victim must be the LRU way. This is the assumption the
    //     flat predictor relies on but never re-implements.
    generate
        if(WAY > 1)
        begin : gen_repl_checks
            always @(posedge clk)
                if(rst)
                begin
                    if(any_invalid(CpuIdx))
                        assert(!valid_reg[CpuIdx][victim_way])
                            else $error("cache_sva: victim way %0d valid while an invalid way exists (set %0d)",
                                        victim_way, CpuIdx);
                    else
                        assert(victim_way == lru_way[CpuIdx])
                            else $error("cache_sva: all ways valid but victim %0d != lru_way %0d (set %0d)",
                                        victim_way, lru_way[CpuIdx], CpuIdx);
                end
        end
    endgenerate

endmodule
