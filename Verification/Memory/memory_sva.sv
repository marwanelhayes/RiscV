// =============================================================================
// memory_sva.sv
// -----------------------------------------------------------------------------
// MEM/WB timing assertions, bound by module type (mem_top, risc_top):
//   bind memory_stage memory_sva MemorySva (.*);
// D-cache timing lives in cache_sva.sv.
//
// A extension (memory_stage header): reservation set/clear, AMO* read-then-
// write sequencing, "an SC / AMO* touches the cache exactly once", the SC
// status result and the amo_unit write value (checked against a spec-level
// reference: .W ops on the low 32 bits, .D ops on the full XLEN).
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
    input logic [FINAL_DATA_WIDTH-1:0] ResAddr,

    // ── amo_unit ────────────────────────────────────────────────────────────────
    input amo_op_t AmoOpM,
    input logic [2:0] funct3M,
    input logic [FINAL_DATA_WIDTH-1:0] WriteDataM, AtomicResult, AmoNewM
);
    localparam int XLEN = FINAL_DATA_WIDTH;

    // Spec-level AMO* value: op(old memory value, rs2) at the access width
    function automatic logic [XLEN-1:0] amo_x(amo_op_t op, logic [XLEN-1:0] a, b);
        case (op)
            AMO_ADD:  return a + b;
            AMO_XOR:  return a ^ b;
            AMO_AND:  return a & b;
            AMO_OR:   return a | b;
            AMO_MIN:  return ($signed(a) < $signed(b)) ? a : b;
            AMO_MAX:  return ($signed(a) > $signed(b)) ? a : b;
            AMO_MINU: return (a < b) ? a : b;
            AMO_MAXU: return (a > b) ? a : b;
            default:  return b;                                 // AMO_SWAP
        endcase
    endfunction
    function automatic logic [31:0] amo_w(amo_op_t op, logic [31:0] a, b);
        case (op)
            AMO_ADD:  return a + b;
            AMO_XOR:  return a ^ b;
            AMO_AND:  return a & b;
            AMO_OR:   return a | b;
            AMO_MIN:  return ($signed(a) < $signed(b)) ? a : b;
            AMO_MAX:  return ($signed(a) > $signed(b)) ? a : b;
            AMO_MINU: return (a < b) ? a : b;
            AMO_MAXU: return (a > b) ? a : b;
            default:  return b;                                 // AMO_SWAP
        endcase
    endfunction

    logic IsWordM, ScOkM;
    assign IsWordM = (load_store_t'(funct3M) == W);
    assign ScOkM   = ResValid && (ResAddr == ALUOutM);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_stall: assert property (StallW |=> $stable({ValidW, RdW, RegWriteW, ReadDataW, ALUOutW}))
        else uvm_report_error("SVA_MEMORY", "MEM/WB changed while StallW");
    a_stall_cover: cover property (StallW |=> $stable({ValidW, RdW, RegWriteW, ReadDataW, ALUOutW}));
    a_advance: assert property (!StallW |=> ValidW == $past(ValidM) && RdW == $past(RdM) && RegWriteW == $past(RegWriteM) &&
                                ALUOutW == $past(ALUOutM) && ReadDataW == $past(ResultDataM))
        else uvm_report_error("SVA_MEMORY", "MEM/WB did not capture the MEM result");
    a_advance_cover: cover property (!StallW |=> ValidW == $past(ValidM) && RdW == $past(RdM) && RegWriteW == $past(RegWriteM) &&
                                ALUOutW == $past(ALUOutM) && ReadDataW == $past(ResultDataM));
    a_known: assert property (!$isunknown({ValidW, RegWriteW, ResValid, AmoWritePhase, AtomicDone}))
        else uvm_report_error("SVA_MEMORY", "X on MEM/WB or atomic control");
    a_known_cover: cover property (!$isunknown({ValidW, RegWriteW, ResValid, AmoWritePhase, AtomicDone}));

    // ── A extension ─────────────────────────────────────────────────────────────
    a_rmw_leaves_after_write: assert property ((IsRmwM && !StallW) |-> (AtomicDoneNowM || AtomicDone))
        else uvm_report_error("SVA_MEMORY", "AMO* left MEM without its cache write");
    a_rmw_leaves_after_write_cover: cover property ((IsRmwM && !StallW) |-> (AtomicDoneNowM || AtomicDone));
    a_rmw_read_then_write: assert property (RmwReadDoneM |=> AmoWritePhase && IsRmwM)
        else uvm_report_error("SVA_MEMORY", "AMO* read half not followed by its write half");
    a_rmw_read_then_write_cover: cover property (RmwReadDoneM |=> AmoWritePhase && IsRmwM);
    a_rmw_write_after_read: assert property ($rose(AmoWritePhase) |-> $past(RmwReadDoneM))
        else uvm_report_error("SVA_MEMORY", "AMO* write half without a read half");
    a_rmw_write_after_read_cover: cover property ($rose(AmoWritePhase) |-> $past(RmwReadDoneM));
    a_rmw_no_read_in_write: assert property ((IsRmwM && AmoWritePhase) |-> !CacheReadEnM)
        else uvm_report_error("SVA_MEMORY", "AMO* write half also reads the cache");
    a_rmw_no_read_in_write_cover: cover property ((IsRmwM && AmoWritePhase) |-> !CacheReadEnM);
    a_done_no_access: assert property (AtomicDone |-> !(CacheReadEnM || CacheWriteEnM))
        else uvm_report_error("SVA_MEMORY", "SC / AMO* touched the cache again after it was done");
    a_done_no_access_cover: cover property (AtomicDone |-> !(CacheReadEnM || CacheWriteEnM));
    a_done_only_frozen: assert property (AtomicDoneNowM && !StallW |=> !AtomicDone)
        else uvm_report_error("SVA_MEMORY", "AtomicDone set although MEM/WB advanced");
    a_done_only_frozen_cover: cover property (AtomicDoneNowM && !StallW |=> !AtomicDone);
    a_sc_needs_reservation: assert property ((IsScM && CacheWriteEnM) |-> (ResValid && (ResAddr == ALUOutM)))
        else uvm_report_error("SVA_MEMORY", "SC writes without a matching reservation");
    a_sc_needs_reservation_cover: cover property ((IsScM && CacheWriteEnM) |-> (ResValid && (ResAddr == ALUOutM)));
    a_sc_clears_reservation: assert property ((IsScM && AtomicDoneNowM) |=> !ResValid)
        else uvm_report_error("SVA_MEMORY", "SC did not clear the reservation");
    a_sc_clears_reservation_cover: cover property ((IsScM && AtomicDoneNowM) |=> !ResValid);
    a_lr_sets_reservation: assert property ((IsLrM && CacheHitC) |=> (ResValid && (ResAddr == $past(ALUOutM))))
        else uvm_report_error("SVA_MEMORY", "LR did not register its reservation");
    a_lr_sets_reservation_cover: cover property ((IsLrM && CacheHitC) |=> (ResValid && (ResAddr == $past(ALUOutM))));
    a_res_only_lr: assert property ($rose(ResValid) |-> $past(IsLrM && CacheHitC))
        else uvm_report_error("SVA_MEMORY", "reservation set by something other than LR");
    a_res_only_lr_cover: cover property ($rose(ResValid) |-> $past(IsLrM && CacheHitC));

    // ── amo_unit / atomic results ───────────────────────────────────────────────
    a_amo_value: assert property ((IsRmwM && AmoWritePhase) |->
                                  (IsWordM ? (AmoNewM[31:0] == amo_w(AmoOpM, AtomicResult[31:0], WriteDataM[31:0]))
                                           : (AmoNewM == amo_x(AmoOpM, AtomicResult, WriteDataM))))
        else uvm_report_error("SVA_MEMORY", "amo_unit write value does not match op(old, rs2)");
    a_amo_value_cover: cover property ((IsRmwM && AmoWritePhase) |->
                                  (IsWordM ? (AmoNewM[31:0] == amo_w(AmoOpM, AtomicResult[31:0], WriteDataM[31:0]))
                                           : (AmoNewM == amo_x(AmoOpM, AtomicResult, WriteDataM))));
    a_amo_rd_old: assert property ((IsRmwM && AmoWritePhase) |-> ResultDataM == AtomicResult)
        else uvm_report_error("SVA_MEMORY", "AMO* rd is not the old memory value");
    a_amo_rd_old_cover: cover property ((IsRmwM && AmoWritePhase) |-> ResultDataM == AtomicResult);
    a_sc_result: assert property ((IsScM && !AtomicDone) |-> ResultDataM == XLEN'(!ScOkM))
        else uvm_report_error("SVA_MEMORY", "SC rd is not 0 on success / 1 on failure");
    a_sc_result_cover: cover property ((IsScM && !AtomicDone) |-> ResultDataM == XLEN'(!ScOkM));
    a_sc_fail_no_write: assert property ((IsScM && !ScOkM) |-> !CacheWriteEnM)
        else uvm_report_error("SVA_MEMORY", "failed SC wrote the cache");
    a_sc_fail_no_write_cover: cover property ((IsScM && !ScOkM) |-> !CacheWriteEnM);

    // Scenario covers: every AMO* op completes, SC succeeds and fails
    localparam amo_op_t RMW_OPS [9] = '{AMO_SWAP, AMO_ADD, AMO_XOR, AMO_AND, AMO_OR,
                                         AMO_MIN, AMO_MAX, AMO_MINU, AMO_MAXU};
    for (genvar i = 0; i < 9; i++) begin : g_amo_op
        c_amo_op_done: cover property (IsRmwM && AtomicDoneNowM && AmoOpM == RMW_OPS[i]);
    end
    c_sc_success: cover property (IsScM && AtomicDoneNowM && ScOkM);
    c_sc_fail: cover property (IsScM && AtomicDoneNowM && !ScOkM);
    c_atomic_frozen: cover property (AtomicDoneNowM && StallW ##1 AtomicDone);
endmodule
