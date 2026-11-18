// =============================================================================
// decode_sva.sv
// -----------------------------------------------------------------------------
// ID/EX timing and register-file write-through assertions, bound by module
// type (decode_top, risc_top):
//   bind decode_stage decode_sva DecodeSva (.*);
// A extension: AmoE / AmoOpE travel through ID/EX like the other controls,
// and a legal AMO opcode decodes as LR (read), SC (write) or AMO* (both).
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module decode_sva (
    input logic clk, rst,
    input logic StallE, FlushE,
    input logic ValidD, ValidE,
    input gpr_t RdD, RdE, Rs1D, Rs2D, RdW,
    input logic RegWriteD, RegWriteE, MemWriteE, FPURegWriteE, FPUValidD, FPUValidE, RegWriteW,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4D, PCPlus4E, RD1D, RD2D, ResultW,

    // ── A extension ─────────────────────────────────────────────────────────────
    input opcode_t opcodeD,
    input logic IllegaleInstructionD, MemReadD, MemWriteD, AmoD, AmoE,
    input amo_op_t AmoOpD, AmoOpE
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_flush: assert property (FlushE |=> !ValidE && !RegWriteE && !MemWriteE && !FPURegWriteE && !FPUValidE && !AmoE && RdE == zero)
        else uvm_report_error("SVA_DECODE", "FlushE did not leave a bubble in ID/EX");
    a_flush_cover: cover property (FlushE |=> !ValidE && !RegWriteE && !MemWriteE && !FPURegWriteE && !FPUValidE && !AmoE && RdE == zero);
    a_stall: assert property (StallE && !FlushE |=> $stable({ValidE, RdE, RegWriteE, FPUValidE, PCPlus4E, AmoE, AmoOpE}))
        else uvm_report_error("SVA_DECODE", "ID/EX changed while StallE");
    a_stall_cover: cover property (StallE && !FlushE |=> $stable({ValidE, RdE, RegWriteE, FPUValidE, PCPlus4E, AmoE, AmoOpE}));
    a_advance: assert property (!StallE && !FlushE |=> ValidE == $past(ValidD) && RdE == $past(RdD) &&
                                RegWriteE == $past(RegWriteD) && FPUValidE == $past(FPUValidD) && PCPlus4E == $past(PCPlus4D) &&
                                AmoE == $past(AmoD) && AmoOpE == $past(AmoOpD))
        else uvm_report_error("SVA_DECODE", "ID/EX did not capture the decoded instruction");
    a_advance_cover: cover property (!StallE && !FlushE |=> ValidE == $past(ValidD) && RdE == $past(RdD) &&
                                RegWriteE == $past(RegWriteD) && FPUValidE == $past(FPUValidD) && PCPlus4E == $past(PCPlus4D) &&
                                AmoE == $past(AmoD) && AmoOpE == $past(AmoOpD));
    // GPR file writes on negedge, so a WB write is visible to decode the same cycle
    a_wt_rs1: assert property (RegWriteW && RdW != zero && Rs1D == RdW |-> RD1D == ResultW)
        else uvm_report_error("SVA_DECODE", "rs1 read missed same-cycle WB write");
    a_wt_rs1_cover: cover property (RegWriteW && RdW != zero && Rs1D == RdW |-> RD1D == ResultW);
    a_wt_rs2: assert property (RegWriteW && RdW != zero && Rs2D == RdW |-> RD2D == ResultW)
        else uvm_report_error("SVA_DECODE", "rs2 read missed same-cycle WB write");
    a_wt_rs2_cover: cover property (RegWriteW && RdW != zero && Rs2D == RdW |-> RD2D == ResultW);
    a_known: assert property (!$isunknown({ValidE, RegWriteE, MemWriteE, FPUValidE, AmoE}))
        else uvm_report_error("SVA_DECODE", "X on ID/EX control");
    a_known_cover: cover property (!$isunknown({ValidE, RegWriteE, MemWriteE, FPUValidE, AmoE}));

    // ── A extension ─────────────────────────────────────────────────────────────
    a_amo_decode: assert property (opcodeD == AMO && !IllegaleInstructionD |->
                                   AmoD && RegWriteD && MemReadD == (AmoOpD != AMO_SC) && MemWriteD == (AmoOpD != AMO_LR))
        else uvm_report_error("SVA_DECODE", "AMO opcode decoded with wrong LR/SC/AMO* controls");
    a_amo_decode_cover: cover property (opcodeD == AMO && !IllegaleInstructionD |->
                                   AmoD && RegWriteD && MemReadD == (AmoOpD != AMO_SC) && MemWriteD == (AmoOpD != AMO_LR));
    a_amo_only_opcode: assert property (AmoD |-> opcodeD == AMO)
        else uvm_report_error("SVA_DECODE", "AmoD raised for a non-AMO opcode");
    a_amo_only_opcode_cover: cover property (AmoD |-> opcodeD == AMO);
    c_amo_lr: cover property (ValidD && AmoD && !IllegaleInstructionD && AmoOpD == AMO_LR);
    c_amo_sc: cover property (ValidD && AmoD && !IllegaleInstructionD && AmoOpD == AMO_SC);
    c_amo_rmw: cover property (ValidD && AmoD && !IllegaleInstructionD && !(AmoOpD inside {AMO_LR, AMO_SC}));
    c_amo_illegal: cover property (ValidD && opcodeD == AMO && IllegaleInstructionD);
endmodule
