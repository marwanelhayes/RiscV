// =============================================================================
// wb_sva.sv
// -----------------------------------------------------------------------------
// PC register timing assertions, bound by module type (writeback_top, risc_top):
//   bind wb_stage wb_sva WbSva (.*);
// Priority: trap/mret > taken branch > StallF hold > PC+4.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module wb_sva (
    input logic clk, rst,
    input logic StallF, PCSrcE, TrapIsSet,
    input logic [FINAL_DATA_WIDTH-1:0] PCF, PCPlus4F, PCBranchE, CsrOutPC
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_trap: assert property (TrapIsSet |=> PCF == $past(CsrOutPC))
        else uvm_report_error("SVA_WB", "PC did not take the trap/mret target");
    a_branch: assert property (!TrapIsSet && PCSrcE |=> PCF == $past(PCBranchE))
        else uvm_report_error("SVA_WB", "PC did not take the branch target");
    a_stall: assert property (!TrapIsSet && !PCSrcE && StallF |=> $stable(PCF))
        else uvm_report_error("SVA_WB", "PC changed while StallF");
    a_seq: assert property (!TrapIsSet && !PCSrcE && !StallF |=> PCF == $past(PCPlus4F))
        else uvm_report_error("SVA_WB", "PC did not advance to PC+4");
    a_known: assert property (!$isunknown(PCF))
        else uvm_report_error("SVA_WB", "X on PCF");
endmodule
