// =============================================================================
// csr_sva.sv
// -----------------------------------------------------------------------------
// csr_file timing assertions, bound by module type (csr_top, execute_top,
// risc_top):
//   bind csr_file csr_sva CsrSva (.*);
// State changes only on Commit and lands the next cycle; trap entry / MRET
// update mepc and the mstatus stack one cycle later; mcycle ticks every cycle
// and minstret on every retire unless a CSR write replaces the increment.
// B3: trap entry stacks the mode into MPP and enters M, MRET restores it and
// leaves MPP = U, the mode changes only on a trap, MRET or SRET, MPP holds
// U, S or M; WfiWait sets when a WFI retires and clears on a pending enabled line
// (mip & mie, never gated by mstatus.MIE or the mode).
// =============================================================================
import uvm_pkg::*;
import shared_pkg::*;

module csr_sva (
    input logic clk, rst,
    input logic Commit, TrapTaken, MretTaken, SretTaken, ToS, TrapIsSet, Retire, CounterWrite, CsrAccess, CsrWrite, mret,
    input csr_index_t CsrIndex,
    input logic [FINAL_DATA_WIDTH-1:0] PC, Address, CsrWriteData, CsrOutPC, Mtvec, Mscratch, Mepc, Mcause, Mtval, Sepc, Scause, Stval, Stvec,
    input logic [FINAL_DATA_WIDTH-1:0] ExceptionCause, InterruptCause,
    input logic InterruptPending, IrqToS, CsrIllegal,
    input logic [2:0] Mideleg,
    input logic [1:0] MStatusFS,
    input logic FpOp, FpRegWrite,
    input logic [FINAL_DATA_WIDTH-1:0] MipValue, MieValue,
    input logic MStatusSIE, MStatusSPIE, MStatusSPP, MStatusMIE, MStatusMPIE, MieMEIE, MieMTIE, MieMSIE,
    input priv_mode_t PrivMode, MStatusMPP,
    input logic MStatusMPRV, MStatusTW, Wfi, WfiWait, WfiStall,
    input logic [2:0] Mcounteren,
    input logic [63:0] Mcycle, Minstret,
    input logic [4:0]  Fflags,
    input logic [2:0]  Frm
);
    default clocking @(posedge clk); endclocking
    default disable iff ($sampled(rst) !== 1'b1);   // reset as the flops saw it at this edge

    a_redirect_commit: assert property (TrapIsSet |-> Commit)
        else uvm_report_error("SVA_CSR", "TrapIsSet without Commit");
    a_redirect_commit_cover: cover property (TrapIsSet |-> Commit);
    a_exclusive: assert property ($onehot0({TrapTaken, MretTaken, SretTaken}))
        else uvm_report_error("SVA_CSR", "trap, MRET and SRET taken in the same cycle");
    a_exclusive_cover: cover property ($onehot0({TrapTaken, MretTaken, SretTaken}));
    a_no_commit_hold: assert property (!Commit |=> $stable({MStatusMIE, MStatusMPIE, MieMEIE, MieMTIE, MieMSIE,
                                                            Mtvec, Mscratch, Mepc, Mcause, Mtval, Fflags, Frm, Minstret,
                                                            PrivMode, MStatusMPP, MStatusMPRV, MStatusTW, Mcounteren}))
        else uvm_report_error("SVA_CSR", "CSR state changed without Commit");
    a_no_commit_hold_cover: cover property (!Commit |=> $stable({MStatusMIE, MStatusMPIE, MieMEIE, MieMTIE, MieMSIE,
                                                            Mtvec, Mscratch, Mepc, Mcause, Mtval, Fflags, Frm, Minstret,
                                                            PrivMode, MStatusMPP, MStatusMPRV, MStatusTW, Mcounteren}));
    a_trap_entry: assert property (TrapTaken && !ToS |=> Mepc == {$past(PC[FINAL_DATA_WIDTH-1:2]), 2'b00} &&
                                   !MStatusMIE && MStatusMPIE == $past(MStatusMIE))
        else uvm_report_error("SVA_CSR", "trap entry did not update mepc/mstatus the next cycle");
    a_trap_entry_cover: cover property (TrapTaken && !ToS |=> Mepc == {$past(PC[FINAL_DATA_WIDTH-1:2]), 2'b00} &&
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
    a_known: assert property (!$isunknown({TrapIsSet, TrapTaken, PrivMode, WfiStall}))
        else uvm_report_error("SVA_CSR", "X on TrapIsSet/TrapTaken/PrivMode/WfiStall");
    a_known_cover: cover property (!$isunknown({TrapIsSet, TrapTaken, PrivMode, WfiStall}));

    // ── Privilege mode (B3.2) ───────────────────────────────────────────────
    a_trap_mode: assert property (TrapTaken && !ToS |=> PrivMode == MachineMode && MStatusMPP == $past(PrivMode))
        else uvm_report_error("SVA_CSR", "trap entry did not enter M with MPP = previous mode");
    a_trap_mode_s: assert property (TrapTaken && ToS |=> PrivMode == SupervisorMode && !MStatusSIE &&
                                    MStatusSPIE == $past(MStatusSIE) && MStatusSPP == ($past(PrivMode) == SupervisorMode) &&
                                    Sepc == {$past(PC[FINAL_DATA_WIDTH-1:2]), 2'b00})
        else uvm_report_error("SVA_CSR", "delegated trap entry did not enter S with the SPP/SPIE/sepc update");
    a_trap_mode_s_cover: cover property (TrapTaken && ToS ##1 PrivMode == SupervisorMode);
    a_sret: assert property (SretTaken |=> PrivMode == ($past(MStatusSPP) ? SupervisorMode : UserMode) && !MStatusSPP &&
                             MStatusSIE == $past(MStatusSPIE) && MStatusSPIE && !MStatusMPRV)
        else uvm_report_error("SVA_CSR", "SRET did not restore the mode / mstatus");
    a_sret_cover: cover property (SretTaken ##1 PrivMode == UserMode);
    a_trap_mode_cover: cover property (TrapTaken && PrivMode == UserMode ##1 PrivMode == MachineMode);
    a_mret_mode: assert property (MretTaken |=> PrivMode == $past(MStatusMPP) && MStatusMPP == UserMode &&
                                  ($past(MStatusMPP) == MachineMode || !MStatusMPRV))
        else uvm_report_error("SVA_CSR", "MRET did not restore the mode / clear MPP (and MPRV below M)");
    a_mret_mode_cover: cover property (MretTaken && MStatusMPP == UserMode ##1 PrivMode == UserMode);
    a_mode_change: assert property (PrivMode != $past(PrivMode) |-> $past(TrapTaken || MretTaken || SretTaken))
        else uvm_report_error("SVA_CSR", "privilege mode changed without a trap, MRET or SRET");
    a_mpp_legal: assert property (MStatusMPP inside {UserMode, SupervisorMode, MachineMode} && PrivMode inside {UserMode, SupervisorMode, MachineMode})
        else uvm_report_error("SVA_CSR", "MPP or the mode holds an unimplemented privilege");

    // ── Interrupt arbitration (B4.2) and delegated trap entry ───────────────
    // Written from the spec, not from the RTL's group masks: an interrupt is taken iff some
    // line is pending, enabled in mie and on at the current mode (M-routed: MIE in M, always
    // below; delegated: SIE in S, always in U, never in M). The M-routed group wins, then the
    // order MEI MSI MTI SEI SSI STI.
    function automatic logic [FINAL_DATA_WIDTH-1:0] deleg_bits(logic [2:0] md);   // argument: a continuous assign is only sensitive to its operands
        logic [FINAL_DATA_WIDTH-1:0] d = '0;
        d[9] = md[2]; d[5] = md[1]; d[1] = md[0];
        return d;
    endfunction
    function automatic int irq_prio(logic [FINAL_DATA_WIDTH-1:0] v);
        if(v[11]) return 11;
        if(v[3])  return 3;
        if(v[7])  return 7;
        if(v[9])  return 9;
        if(v[1])  return 1;
        return 5;
    endfunction
    wire [FINAL_DATA_WIDTH-1:0] pend_m = MipValue & MieValue & ~deleg_bits(Mideleg) &
                                         {FINAL_DATA_WIDTH{PrivMode != MachineMode || MStatusMIE}};
    wire [FINAL_DATA_WIDTH-1:0] pend_s = MipValue & MieValue & deleg_bits(Mideleg) &
                                         {FINAL_DATA_WIDTH{PrivMode == UserMode || (PrivMode == SupervisorMode && MStatusSIE)}};
    a_irq: assert property (InterruptPending == (|pend_m || |pend_s))
        else uvm_report_error("SVA_CSR", "an interrupt is taken that is not pending and enabled, or one is missed");
    a_irq_pick: assert property (InterruptPending |-> (|pend_m ? (!IrqToS && int'(InterruptCause) == irq_prio(pend_m))
                                                              : (IrqToS && int'(InterruptCause) == irq_prio(pend_s))))
        else uvm_report_error("SVA_CSR", "interrupt arbitration differs from the B4.2 rules");
    a_irq_cover_s: cover property (InterruptPending && IrqToS && |pend_m == 0 && |pend_s);
    a_irq_cover_m_first: cover property (|pend_m && |pend_s && InterruptPending && !IrqToS);
    a_trap_s: assert property (TrapTaken && ToS |-> CsrOutPC == ({Stvec[FINAL_DATA_WIDTH-1:2], 2'b00} +
                                                               ((InterruptPending && Stvec[0]) ? (InterruptCause << 2) : '0)))
        else uvm_report_error("SVA_CSR", "delegated trap did not redirect to stvec");
    a_trap_s_state: assert property (TrapTaken && ToS |=> Sepc == {$past(PC[FINAL_DATA_WIDTH-1:2]), 2'b00} &&
                                     Scause == $past(InterruptPending ? {1'b1, InterruptCause[FINAL_DATA_WIDTH-2:0]} : ExceptionCause) &&
                                     Stval == $past((InterruptPending || CsrIllegal) ? '0 : Address) &&
                                     MStatusSPP == ($past(PrivMode) == SupervisorMode) && MStatusSPIE == $past(MStatusSIE) && !MStatusSIE &&
                                     PrivMode == SupervisorMode &&
                                     $stable({Mepc, Mcause, Mtval, MStatusMIE, MStatusMPIE, MStatusMPP}))
        else uvm_report_error("SVA_CSR", "delegated trap entry wrong (sepc/scause/stval/SPP/SPIE/SIE) or changed an M CSR");
    a_trap_s_cover: cover property (TrapTaken && ToS && InterruptPending ##1 PrivMode == SupervisorMode);
    a_trap_s_cover_exc: cover property (TrapTaken && ToS && !InterruptPending ##1 PrivMode == SupervisorMode);

    // ── mstatus.FS (B4): an FP register or fcsr write dirties it, nothing else changes it ──
    a_fs_dirty: assert property (Commit && !TrapTaken && FpOp && FpRegWrite |=> MStatusFS == 2'b11)
        else uvm_report_error("SVA_CSR", "FP register write did not set FS = Dirty");
    a_fs_dirty_cover: cover property (Commit && !TrapTaken && FpOp && FpRegWrite && MStatusFS != 2'b11 ##1 MStatusFS == 2'b11);
    a_fs_hold: assert property (!(Commit && CsrAccess && CsrWrite && CsrIndex inside {mstatus, sstatus, fflags, frm, fcsr}) &&
                                !(Commit && !TrapTaken && FpOp && FpRegWrite) |=> $stable(MStatusFS))
        else uvm_report_error("SVA_CSR", "FS changed without an mstatus write, FPR write or fcsr write");
    a_fs_off_trap: assert property (Commit && FpOp && MStatusFS == 2'b00 |-> TrapTaken && CsrIllegal)
        else uvm_report_error("SVA_CSR", "FP instruction with FS = Off did not raise illegal instruction");
    a_fs_off_trap_cover: cover property (Commit && FpOp && MStatusFS == 2'b00 && TrapTaken);

    // ── WFI wait / wake (B3.4) ──────────────────────────────────────────────
    a_wfi_stall: assert property (WfiStall == (WfiWait && !(|(MipValue & MieValue))))
        else uvm_report_error("SVA_CSR", "WfiStall is not WfiWait && no pending enabled line");
    a_wfi_wait: assert property (Commit && Wfi && !TrapTaken |=> WfiWait)
        else uvm_report_error("SVA_CSR", "retired WFI did not start the wait");
    a_wfi_wait_cover: cover property (Commit && Wfi && !TrapTaken ##1 WfiStall);
    a_wfi_wake: assert property (WfiWait && (|(MipValue & MieValue)) && !(Commit && Wfi && !TrapTaken) |=> !WfiWait)
        else uvm_report_error("SVA_CSR", "pending enabled line did not end the WFI wait");
    a_wfi_wake_cover: cover property (WfiStall ##1 WfiWait && (|(MipValue & MieValue)) && !MStatusMIE ##1 !WfiWait);
endmodule
