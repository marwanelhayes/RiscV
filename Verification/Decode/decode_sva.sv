// =============================================================================
// decode_sva.sv
// -----------------------------------------------------------------------------
// ID/EX timing and register-file write-through assertions, bound by module
// type (decode_top, risc_top):
//   bind decode_stage decode_sva DecodeSva (.*);
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module decode_sva (
    input logic clk, rst,
    input logic StallE, FlushE,
    input logic ValidD, ValidE,
    input gpr_t RdD, RdE, Rs1D, Rs2D, RdW,
    input logic RegWriteD, RegWriteE, MemWriteE, FPURegWriteE, FPUValidD, FPUValidE, RegWriteW,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4D, PCPlus4E, RD1D, RD2D, ResultW
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_flush: assert property (FlushE |=> !ValidE && !RegWriteE && !MemWriteE && !FPURegWriteE && !FPUValidE && RdE == zero)
        else uvm_report_error("SVA_DECODE", "FlushE did not leave a bubble in ID/EX");
    a_stall: assert property (StallE && !FlushE |=> $stable({ValidE, RdE, RegWriteE, FPUValidE, PCPlus4E}))
        else uvm_report_error("SVA_DECODE", "ID/EX changed while StallE");
    a_advance: assert property (!StallE && !FlushE |=> ValidE == $past(ValidD) && RdE == $past(RdD) &&
                                RegWriteE == $past(RegWriteD) && FPUValidE == $past(FPUValidD) && PCPlus4E == $past(PCPlus4D))
        else uvm_report_error("SVA_DECODE", "ID/EX did not capture the decoded instruction");
    // GPR file writes on negedge, so a WB write is visible to decode the same cycle
    a_wt_rs1: assert property (RegWriteW && RdW != zero && Rs1D == RdW |-> RD1D == ResultW)
        else uvm_report_error("SVA_DECODE", "rs1 read missed same-cycle WB write");
    a_wt_rs2: assert property (RegWriteW && RdW != zero && Rs2D == RdW |-> RD2D == ResultW)
        else uvm_report_error("SVA_DECODE", "rs2 read missed same-cycle WB write");
    a_known: assert property (!$isunknown({ValidE, RegWriteE, MemWriteE, FPUValidE}))
        else uvm_report_error("SVA_DECODE", "X on ID/EX control");
endmodule
