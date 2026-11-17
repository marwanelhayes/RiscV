// =============================================================================
// execute_sva.sv
// -----------------------------------------------------------------------------
// EX/MEM timing and redirect-gating assertions, bound by module type
// (execute_top, risc_top):
//   bind execute_stage execute_sva ExecuteSva (.*);
// FPU and CSR timing live in fpu_sva.sv / csr_sva.sv.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module execute_sva (
    input logic clk, rst,
    input logic StallE, StallM, FlushM,
    input logic ValidE, ValidM, PCSrcE, TrapIsSet,
    input gpr_t RdE, RdM,
    input logic RegWriteE, RegWriteM, MemWriteE, MemWriteM, MemReadE, MemReadM, FPURegWriteM,
    input logic [FINAL_DATA_WIDTH-1:0] ResultE, ALUOutM
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_flush: assert property (FlushM |=> !ValidM && !RegWriteM && !MemWriteM && !MemReadM && !FPURegWriteM)
        else uvm_report_error("SVA_EXECUTE", "FlushM did not leave a bubble in EX/MEM");
    a_stall: assert property (StallM && !FlushM |=> $stable({ValidM, RdM, RegWriteM, MemWriteM, MemReadM, ALUOutM}))
        else uvm_report_error("SVA_EXECUTE", "EX/MEM changed while StallM");
    a_advance: assert property (!StallM && !FlushM |=> ValidM == $past(ValidE) && RdM == $past(RdE) &&
                                RegWriteM == $past(RegWriteE) && MemWriteM == $past(MemWriteE) && ALUOutM == $past(ResultE))
        else uvm_report_error("SVA_EXECUTE", "EX/MEM did not capture the EX result");
    // A redirect is only raised by a valid EX instruction that advances
    a_redirect_commit: assert property (PCSrcE || TrapIsSet |-> ValidE && !StallE)
        else uvm_report_error("SVA_EXECUTE", "redirect raised while EX is stalled or empty");
    a_one_redirect: assert property (!(PCSrcE && TrapIsSet))
        else uvm_report_error("SVA_EXECUTE", "PCSrcE and TrapIsSet in the same cycle");
    a_known: assert property (!$isunknown({ValidM, RegWriteM, MemWriteM, MemReadM, PCSrcE, TrapIsSet}))
        else uvm_report_error("SVA_EXECUTE", "X on EX/MEM control or redirect");
endmodule
