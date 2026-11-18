// =============================================================================
// execute_sva.sv
// -----------------------------------------------------------------------------
// EX/MEM timing and redirect-gating assertions, bound by module type
// (execute_top, risc_top):
//   bind execute_stage execute_sva ExecuteSva (.*);
// FPU and CSR timing live in fpu_sva.sv / csr_sva.sv.
// A extension: AmoM / AmoOpM travel through EX/MEM like the other controls;
// a misaligned LR faults as a load, a misaligned SC / AMO* as a store/AMO.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module execute_sva (
    input logic clk, rst,
    input logic StallE, StallM, FlushM,
    input logic ValidE, ValidM, PCSrcE, TrapIsSet,
    input gpr_t RdE, RdM,
    input logic RegWriteE, RegWriteM, MemWriteE, MemWriteM, MemReadE, MemReadM, FPURegWriteM,
    input logic [FINAL_DATA_WIDTH-1:0] ResultE, ALUOutM,

    // ── A extension ─────────────────────────────────────────────────────────────
    input logic AmoE, AmoM, IllegaleInstructionE,
    input amo_op_t AmoOpE, AmoOpM,
    input logic [2:0] funct3E,
    input logic [FINAL_DATA_WIDTH-1:0] AddressE,
    input traps_t TrapsE
);
    logic AmoMisalignedE;   // .W needs 4-byte, .D 8-byte alignment
    assign AmoMisalignedE = (load_store_t'(funct3E) == D) ? (|AddressE[2:0]) : (|AddressE[1:0]);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_flush: assert property (FlushM |=> !ValidM && !RegWriteM && !MemWriteM && !MemReadM && !FPURegWriteM && !AmoM)
        else uvm_report_error("SVA_EXECUTE", "FlushM did not leave a bubble in EX/MEM");
    a_flush_cover: cover property (FlushM |=> !ValidM && !RegWriteM && !MemWriteM && !MemReadM && !FPURegWriteM && !AmoM);
    a_stall: assert property (StallM && !FlushM |=> $stable({ValidM, RdM, RegWriteM, MemWriteM, MemReadM, ALUOutM, AmoM, AmoOpM}))
        else uvm_report_error("SVA_EXECUTE", "EX/MEM changed while StallM");
    a_stall_cover: cover property (StallM && !FlushM |=> $stable({ValidM, RdM, RegWriteM, MemWriteM, MemReadM, ALUOutM, AmoM, AmoOpM}));
    a_advance: assert property (!StallM && !FlushM |=> ValidM == $past(ValidE) && RdM == $past(RdE) &&
                                RegWriteM == $past(RegWriteE) && MemWriteM == $past(MemWriteE) && ALUOutM == $past(ResultE) &&
                                AmoM == $past(AmoE) && AmoOpM == $past(AmoOpE))
        else uvm_report_error("SVA_EXECUTE", "EX/MEM did not capture the EX result");
    a_advance_cover: cover property (!StallM && !FlushM |=> ValidM == $past(ValidE) && RdM == $past(RdE) &&
                                RegWriteM == $past(RegWriteE) && MemWriteM == $past(MemWriteE) && ALUOutM == $past(ResultE) &&
                                AmoM == $past(AmoE) && AmoOpM == $past(AmoOpE));
    // A redirect is only raised by a valid EX instruction that advances
    a_redirect_commit: assert property (PCSrcE || TrapIsSet |-> ValidE && !StallE)
        else uvm_report_error("SVA_EXECUTE", "redirect raised while EX is stalled or empty");
    a_redirect_commit_cover: cover property (PCSrcE || TrapIsSet |-> ValidE && !StallE);
    a_one_redirect: assert property (!(PCSrcE && TrapIsSet))
        else uvm_report_error("SVA_EXECUTE", "PCSrcE and TrapIsSet in the same cycle");
    a_one_redirect_cover: cover property (!(PCSrcE && TrapIsSet));
    a_known: assert property (!$isunknown({ValidM, RegWriteM, MemWriteM, MemReadM, AmoM, PCSrcE, TrapIsSet}))
        else uvm_report_error("SVA_EXECUTE", "X on EX/MEM control or redirect");
    a_known_cover: cover property (!$isunknown({ValidM, RegWriteM, MemWriteM, MemReadM, AmoM, PCSrcE, TrapIsSet}));

    // ── A extension ─────────────────────────────────────────────────────────────
    a_amo_trap: assert property (AmoE && !IllegaleInstructionE |->
                                 TrapsE == (!AmoMisalignedE ? NoTraps :
                                            MemWriteE       ? StoreAddressMisalignedOrHyperVisorTimerInterrupt
                                                            : LoadAddressMisalignedOrUserSoftwareInterrupt))
        else uvm_report_error("SVA_EXECUTE", "LR/SC/AMO* misalignment trap wrong");
    a_amo_trap_cover: cover property (AmoE && !IllegaleInstructionE |->
                                 TrapsE == (!AmoMisalignedE ? NoTraps :
                                            MemWriteE       ? StoreAddressMisalignedOrHyperVisorTimerInterrupt
                                                            : LoadAddressMisalignedOrUserSoftwareInterrupt));
    c_amo_misaligned_load: cover property (ValidE && AmoE && !IllegaleInstructionE && AmoMisalignedE && !MemWriteE);
    c_amo_misaligned_store: cover property (ValidE && AmoE && !IllegaleInstructionE && AmoMisalignedE && MemWriteE);
endmodule
