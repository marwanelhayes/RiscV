// =============================================================================
// csr_sva.sv
// -----------------------------------------------------------------------------
// csr_file timing assertions, bound by module type (csr_top, execute_top,
// risc_top):
//   bind csr_file csr_sva CsrSva (.*);
// State changes only on Commit and lands the next cycle; trap entry / MRET
// update mepc and the mstatus stack one cycle later; mcycle ticks every cycle
// and minstret on every retire unless a CSR write replaces the increment.
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module csr_sva (
    input logic clk, rst,
    input logic Commit, TrapTaken, MretTaken, TrapIsSet, Retire, CounterWrite, CsrAccess, CsrWrite, mret,
    input csr_index_t CsrIndex,
    input logic [FINAL_DATA_WIDTH-1:0] PC, CsrWriteData, CsrOutPC, Mtvec, Mscratch, Mepc, Mcause, Mtval,
    input logic MStatusMIE, MStatusMPIE, MieMEIE, MieMTIE, MieMSIE,
    input logic [63:0] Mcycle, Minstret,
    input logic [4:0]  Fflags,
    input logic [2:0]  Frm
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_redirect_commit: assert property (TrapIsSet |-> Commit)
        else uvm_report_error("SVA_CSR", "TrapIsSet without Commit");
    a_redirect_commit_cover: cover property (TrapIsSet |-> Commit);
    a_exclusive: assert property (!(TrapTaken && MretTaken))
        else uvm_report_error("SVA_CSR", "trap and MRET taken in the same cycle");
    a_exclusive_cover: cover property (!(TrapTaken && MretTaken));
    a_no_commit_hold: assert property (!Commit |=> $stable({MStatusMIE, MStatusMPIE, MieMEIE, MieMTIE, MieMSIE,
                                                            Mtvec, Mscratch, Mepc, Mcause, Mtval, Fflags, Frm, Minstret}))
        else uvm_report_error("SVA_CSR", "CSR state changed without Commit");
    a_no_commit_hold_cover: cover property (!Commit |=> $stable({MStatusMIE, MStatusMPIE, MieMEIE, MieMTIE, MieMSIE,
                                                            Mtvec, Mscratch, Mepc, Mcause, Mtval, Fflags, Frm, Minstret}));
    a_trap_entry: assert property (TrapTaken |=> Mepc == {$past(PC[FINAL_DATA_WIDTH-1:2]), 2'b00} &&
                                   !MStatusMIE && MStatusMPIE == $past(MStatusMIE))
        else uvm_report_error("SVA_CSR", "trap entry did not update mepc/mstatus the next cycle");
    a_trap_entry_cover: cover property (TrapTaken |=> Mepc == {$past(PC[FINAL_DATA_WIDTH-1:2]), 2'b00} &&
                                   !MStatusMIE && MStatusMPIE == $past(MStatusMIE));
    a_mret: assert property (MretTaken |=> MStatusMIE == $past(MStatusMPIE) && MStatusMPIE)
        else uvm_report_error("SVA_CSR", "MRET did not restore mstatus the next cycle");
    a_mret_cover: cover property (MretTaken |=> MStatusMIE == $past(MStatusMPIE) && MStatusMPIE);
    a_write_next: assert property (Commit && !TrapTaken && !mret && CsrAccess && CsrWrite && CsrIndex == mscratch
                                   |=> Mscratch == $past(CsrWriteData))
        else uvm_report_error("SVA_CSR", "CSR write not visible the next cycle (mscratch)");
    a_write_next_cover: cover property (Commit && !TrapTaken && !mret && CsrAccess && CsrWrite && CsrIndex == mscratch
                                   |=> Mscratch == $past(CsrWriteData));
    a_mcycle: assert property (!(CounterWrite && CsrIndex inside {mcycle, mcycleh}) |=> Mcycle == $past(Mcycle) + 64'd1)
        else uvm_report_error("SVA_CSR", "mcycle did not tick");
    a_mcycle_cover: cover property (!(CounterWrite && CsrIndex inside {mcycle, mcycleh}) |=> Mcycle == $past(Mcycle) + 64'd1);
    a_minstret: assert property (!(CounterWrite && CsrIndex inside {minstret, minstreth}) |=> Minstret == $past(Minstret + 64'(Retire)))
        else uvm_report_error("SVA_CSR", "minstret did not follow Retire");
    a_minstret_cover: cover property (!(CounterWrite && CsrIndex inside {minstret, minstreth}) |=> Minstret == $past(Minstret + 64'(Retire)));
    a_target_aligned: assert property (TrapIsSet |-> CsrOutPC[1:0] == 2'b00)
        else uvm_report_error("SVA_CSR", "redirect target not 4-byte aligned");
    a_target_aligned_cover: cover property (TrapIsSet |-> CsrOutPC[1:0] == 2'b00);
    a_known: assert property (!$isunknown({TrapIsSet, TrapTaken}))
        else uvm_report_error("SVA_CSR", "X on TrapIsSet/TrapTaken");
    a_known_cover: cover property (!$isunknown({TrapIsSet, TrapTaken}));
endmodule
