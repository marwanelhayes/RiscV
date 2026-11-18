// =============================================================================
// fetch_sva.sv
// -----------------------------------------------------------------------------
// IF/ID timing assertions, bound by module type (fetch_top, risc_top):
//   bind fetch_stage fetch_sva FetchSva (.*);
// Register contract: reset > flush (NOP bubble) > stall (hold) > advance.
// Failures go through uvm_report_error so regress.sh counts them.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module fetch_sva (
    input logic clk, rst,
    input logic StallD, FlushD,
    input logic [FINAL_DATA_WIDTH-1:0] PCF, PCPlus4F, PCPlus4D,
    input logic [INSTR_WIDTH-1:0]      InstructionF, InstructionD,
    input logic ValidD
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_pc_plus4: assert property (PCPlus4F == PCF + FINAL_DATA_WIDTH'(4))
        else uvm_report_error("SVA_FETCH", "PCPlus4F != PCF + 4");
    a_pc_plus4_cover: cover property (PCPlus4F == PCF + FINAL_DATA_WIDTH'(4));
    a_flush: assert property (FlushD |=> !ValidD && InstructionD == 32'h13 && PCPlus4D == '0)
        else uvm_report_error("SVA_FETCH", "FlushD did not leave a NOP bubble in IF/ID");
    a_flush_cover: cover property (FlushD |=> !ValidD && InstructionD == 32'h13 && PCPlus4D == '0);
    a_stall: assert property (StallD && !FlushD |=> $stable(ValidD) && $stable(InstructionD) && $stable(PCPlus4D))
        else uvm_report_error("SVA_FETCH", "IF/ID changed while StallD");
    a_stall_cover: cover property (StallD && !FlushD |=> $stable(ValidD) && $stable(InstructionD) && $stable(PCPlus4D));
    a_advance: assert property (!StallD && !FlushD |=> ValidD && InstructionD == $past(InstructionF) && PCPlus4D == $past(PCPlus4F))
        else uvm_report_error("SVA_FETCH", "IF/ID did not capture the fetched instruction");
    a_advance_cover: cover property (!StallD && !FlushD |=> ValidD && InstructionD == $past(InstructionF) && PCPlus4D == $past(PCPlus4F));
    a_known: assert property (!$isunknown({ValidD, InstructionD}))
        else uvm_report_error("SVA_FETCH", "X on ValidD/InstructionD");
    a_known_cover: cover property (!$isunknown({ValidD, InstructionD}));
endmodule
