// =============================================================================
// memory_sva.sv
// -----------------------------------------------------------------------------
// MEM/WB timing assertions, bound by module type (mem_top, risc_top):
//   bind memory_stage memory_sva MemorySva (.*);
// D-cache timing lives in cache_sva.sv.
//
// A extension (memory_stage header): reservation set/clear, AMO* read-then-
// write sequencing, and "an SC / AMO* touches the cache exactly once".
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module memory_sva (
    input logic clk, rst,
    input logic StallW,
    input logic ValidM, ValidW, RegWriteM, RegWriteW,
    input gpr_t RdM, RdW,
    input logic [FINAL_DATA_WIDTH-1:0] ResultDataM, ReadDataW, ALUOutM, ALUOutW,

    // ── A extension ─────────────────────────────────────────────────────────────
    input logic IsLrM, IsScM, IsRmwM,
    input logic CacheReadEnM, CacheWriteEnM, CacheHitC,
    input logic RmwReadDoneM, AtomicDoneNowM, AmoWritePhase, AtomicDone,
    input logic ResValid,
    input logic [FINAL_DATA_WIDTH-1:0] ResAddr
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_stall: assert property (StallW |=> $stable({ValidW, RdW, RegWriteW, ReadDataW, ALUOutW}))
        else uvm_report_error("SVA_MEMORY", "MEM/WB changed while StallW");
    a_advance: assert property (!StallW |=> ValidW == $past(ValidM) && RdW == $past(RdM) && RegWriteW == $past(RegWriteM) &&
                                ALUOutW == $past(ALUOutM) && ReadDataW == $past(ResultDataM))
        else uvm_report_error("SVA_MEMORY", "MEM/WB did not capture the MEM result");
    a_known: assert property (!$isunknown({ValidW, RegWriteW, ResValid, AmoWritePhase, AtomicDone}))
        else uvm_report_error("SVA_MEMORY", "X on MEM/WB or atomic control");

    // ── A extension ─────────────────────────────────────────────────────────────
    a_rmw_leaves_after_write: assert property ((IsRmwM && !StallW) |-> (AtomicDoneNowM || AtomicDone))
        else uvm_report_error("SVA_MEMORY", "AMO* left MEM without its cache write");
    a_rmw_read_then_write: assert property (RmwReadDoneM |=> AmoWritePhase && IsRmwM)
        else uvm_report_error("SVA_MEMORY", "AMO* read half not followed by its write half");
    a_rmw_write_after_read: assert property ($rose(AmoWritePhase) |-> $past(RmwReadDoneM))
        else uvm_report_error("SVA_MEMORY", "AMO* write half without a read half");
    a_rmw_no_read_in_write: assert property ((IsRmwM && AmoWritePhase) |-> !CacheReadEnM)
        else uvm_report_error("SVA_MEMORY", "AMO* write half also reads the cache");
    a_done_no_access: assert property (AtomicDone |-> !(CacheReadEnM || CacheWriteEnM))
        else uvm_report_error("SVA_MEMORY", "SC / AMO* touched the cache again after it was done");
    a_done_only_frozen: assert property (AtomicDoneNowM && !StallW |=> !AtomicDone)
        else uvm_report_error("SVA_MEMORY", "AtomicDone set although MEM/WB advanced");
    a_sc_needs_reservation: assert property ((IsScM && CacheWriteEnM) |-> (ResValid && (ResAddr == ALUOutM)))
        else uvm_report_error("SVA_MEMORY", "SC writes without a matching reservation");
    a_sc_clears_reservation: assert property ((IsScM && AtomicDoneNowM) |=> !ResValid)
        else uvm_report_error("SVA_MEMORY", "SC did not clear the reservation");
    a_lr_sets_reservation: assert property ((IsLrM && CacheHitC) |=> (ResValid && (ResAddr == $past(ALUOutM))))
        else uvm_report_error("SVA_MEMORY", "LR did not register its reservation");
    a_res_only_lr: assert property ($rose(ResValid) |-> $past(IsLrM && CacheHitC))
        else uvm_report_error("SVA_MEMORY", "reservation set by something other than LR");
endmodule
