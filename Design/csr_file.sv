// =============================================================================
// csr_file.sv
// -----------------------------------------------------------------------------
// Control and Status Register (CSR) file for RISC-V processor (M, S and U mode).
//
// Responsibilities:
//   - Hold the machine and supervisor CSRs as explicit registers (no CSR array);
//     sstatus, sie and sip are views of the machine state
//   - Read any implemented CSR combinationally; flag unknown CSRs as illegal
//   - Route traps to M or S (medeleg/mideleg) and pick the interrupt to take
//   - Take traps (exceptions and interrupts), MRET and SRET in the same cycle the
//     instruction is in EX, so the trapping instruction never commits
//   - Process CSR read/write operations (CSRRW, CSRRS, CSRRC, etc.)
//   - Hold the privilege mode; check CSR privilege, mcounteren, MRET and WFI
//   - Count cycles and retired instructions (64-bit on RV32 and RV64)
//   - Read time/timeh from the MTime input
//   - Hold the instruction after a WFI in EX until an interrupt is pending
//   - Provide rounding mode for FPU operations
//
// Every state update happens only on Commit (a valid EX instruction that
// advances this cycle), so a stalled pipeline never repeats a side effect.
// The one exception is WfiWait, which clears when an interrupt is pending.
// =============================================================================
import shared_pkg::*;
`include "csr_defs.sv"

module csr_file
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ─── CSR operation interface ─────────────────────────────────────────────
    input csr_t CsrOperation,             // CSR operation type
    input gpr_t Rs,                       // rs1 index (uimm for the immediate forms)
    input traps_t Traps,                  // Synchronous exception of the EX instruction
    input mret,                           // MRET instruction flag
    input sret,                           // SRET instruction flag
    input [DATA_WIDTH-1:0] PC,            // PC of the EX instruction (for mepc)
    input [DATA_WIDTH-1:0] Address,       // Trap value for the exception (for mtval)
    input CsrAccess,                      // CSR access enable
    input [DATA_WIDTH-1:0] CsrIn,         // CSR write data (forwarded rs1)
    input Commit,                         // Valid EX instruction that advances this cycle
    input Wfi,                            // WFI instruction flag
    input FpOp,                           // Valid FP instruction in EX (needs mstatus.FS != Off)
    input FpRegWrite,                     // That FP instruction writes an FPR (sets FS = Dirty)
    input [63:0] MTime,                   // Machine timer (time/timeh)

    // ─── Interrupt inputs ─────────────────────────────────────────────────────
    input TimerInterrupt,                 // Timer interrupt
    input ExternalInterrupt,              // External hardware interrupt
    input SoftwareInterrupt,              // Software interrupt
    input SExternalInterrupt,             // Supervisor external interrupt line (PLIC context 1)

    // ─── CSR register index ───────────────────────────────────────────────────
    input csr_index_t CsrIndex,           // CSR address

    // ─── Outputs ───────────────────────────────────────────────────────────────
    output logic [DATA_WIDTH-1:0] CsrOutPC,   // Redirect target: trap vector, mepc or sepc
    output logic [DATA_WIDTH-1:0] CsrOut,     // CSR read data
    output logic TrapIsSet,                   // Redirect now: trap taken, MRET or SRET
    output logic TrapTaken,                   // Exception or interrupt taken: squash EX
    output round_mode_t RoundingMode,         // FPU rounding mode
    output priv_mode_t PrivMode,              // Current privilege mode
    output logic WfiStall                     // Hold EX: after WFI, no interrupt pending
);

    localparam bit IS_RV64 = (DATA_WIDTH == 64);
    localparam logic [1:0] MXL = IS_RV64 ? 2'd2 : 2'd1;
    localparam logic [DATA_WIDTH-1:0] MISA_VALUE = {MXL, {(DATA_WIDTH-2){1'b0}}}
                                                 | (DATA_WIDTH'(1) << `MISA_A)
                                                 | (DATA_WIDTH'(1) << `MISA_I)
                                                 | (DATA_WIDTH'(1) << `MISA_M)
                                                 | (DATA_WIDTH'(1) << `MISA_F)
                                                 | (DATA_WIDTH'(1) << `MISA_S)
                                                 | (DATA_WIDTH'(1) << `MISA_U);
    localparam logic [DATA_WIDTH-1:0] MVENDORID_VALUE = DATA_WIDTH'(32'h48_41_4E_4F);
    localparam logic [63:0] MSTATUS_UXL64 = 64'd2 << `UXLS;     // UXL = 64-bit (zero at RV32)
    localparam logic [63:0] MSTATUS_SXL64 = 64'd2 << `SXLS;     // SXL = 64-bit (zero at RV32)
    // sstatus = mstatus & mask: SIE, SPIE, SPP, FS, SD (+ UXL on RV64)
    localparam logic [DATA_WIDTH-1:0] SSTATUS_MASK = DATA_WIDTH'(IS_RV64 ? 64'h8000_0002_0000_6122
                                                                        : 64'h0000_0000_8000_6122);
    localparam logic [19:0] MEDELEG_MASK = 20'h8_03FF;          // bits 0-9 and 19 (Spike)

    // ─── Architectural state ──────────────────────────────────────────────────
    logic                  MStatusMIE;      // mstatus.MIE
    logic                  MStatusMPIE;     // mstatus.MPIE
    priv_mode_t            MStatusMPP;      // mstatus.MPP (U, S or M)
    logic                  MStatusSIE;      // mstatus.SIE
    logic                  MStatusSPIE;     // mstatus.SPIE
    logic                  MStatusSPP;      // mstatus.SPP (1 = S, 0 = U)
    logic                  MStatusTSR;      // mstatus.TSR
    logic                  MStatusMPRV;     // mstatus.MPRV
    logic                  MStatusTW;       // mstatus.TW
    logic [1:0]            MStatusFS;       // mstatus.FS (0 Off, 1 Initial, 2 Clean, 3 Dirty)
    logic [2:0]            Mcounteren;      // mcounteren.{IR, TM, CY}
    logic [2:0]            Scounteren;      // scounteren.{IR, TM, CY}
    logic [19:0]           Medeleg;         // medeleg (bits of MEDELEG_MASK)
    logic [2:0]            Mideleg;         // mideleg.{SEI, STI, SSI}
    logic                  WfiWait;         // WFI retired, waiting for an interrupt
    logic                  MieMEIE;         // mie.MEIE
    logic                  MieMTIE;         // mie.MTIE
    logic                  MieMSIE;         // mie.MSIE
    logic                  MieSEIE;         // mie.SEIE
    logic                  MieSTIE;         // mie.STIE
    logic                  MieSSIE;         // mie.SSIE
    logic                  MipSeipSw;       // mip.SEIP software bit
    logic                  MipStip;         // mip.STIP
    logic                  MipSsip;         // mip.SSIP
    logic [DATA_WIDTH-1:0] Mtvec;           // mtvec (bit 1 always 0)
    logic [DATA_WIDTH-1:0] Mscratch;        // mscratch
    logic [DATA_WIDTH-1:0] Mepc;            // mepc (bits 1:0 always 0)
    logic [DATA_WIDTH-1:0] Mcause;          // mcause
    logic [DATA_WIDTH-1:0] Mtval;           // mtval
    logic [DATA_WIDTH-1:0] Stvec;           // stvec (bit 1 always 0)
    logic [DATA_WIDTH-1:0] Sscratch;        // sscratch
    logic [DATA_WIDTH-1:0] Sepc;            // sepc (bits 1:0 always 0)
    logic [DATA_WIDTH-1:0] Scause;          // scause
    logic [DATA_WIDTH-1:0] Stval;           // stval
    logic [63:0]           Mcycle;          // mcycle (+ mcycleh on RV32)
    logic [63:0]           Minstret;        // minstret (+ minstreth on RV32)
    logic [4:0]            Fflags;          // fflags
    logic [2:0]            Frm;             // frm

    // ─── Internal wires ───────────────────────────────────────────────────────
    logic [DATA_WIDTH-1:0] MStatusValue;    // mstatus as read
    logic [DATA_WIDTH-1:0] MieValue;        // mie as read
    logic [DATA_WIDTH-1:0] MipValue;        // mip as read
    logic [DATA_WIDTH-1:0] SstatusValue;    // sstatus as read
    logic [DATA_WIDTH-1:0] MidelegMask;     // mideleg spread to the mip/mie bit positions
    logic [DATA_WIDTH-1:0] CsrBase;         // CSR value that csrrs/csrrc modify
    logic                  CsrExists;       // CsrIndex names an implemented CSR
    logic                  CounterGated;    // Counter read blocked by mcounteren/scounteren
    logic                  PrivIllegal;     // Illegal in the current privilege mode
    logic                  CsrIllegal;      // Unknown CSR or privilege violation
    logic                  WfiWake;         // Interrupt pending locally (mip & mie)
    logic                  CsrWrite;        // This CSR instruction writes its CSR
    logic [DATA_WIDTH-1:0] CsrWriteData;    // Value written by the CSR instruction
    logic [DATA_WIDTH-1:0] Uimm;            // Zero-extended immediate operand
    logic                  ExceptionValid;  // Synchronous exception of the EX instruction
    logic [DATA_WIDTH-1:0] ExceptionCause;  // mcause code of the exception
    logic [DATA_WIDTH-1:0] IrqPendM;        // Enabled pending interrupts routed to M
    logic [DATA_WIDTH-1:0] IrqPendS;        // Enabled pending interrupts delegated to S
    logic [DATA_WIDTH-1:0] IrqSel;          // Interrupts of the group taken first
    logic                  InterruptPending;// Enabled interrupt waiting
    logic                  IrqToS;          // The interrupt is delegated to S
    logic [DATA_WIDTH-1:0] InterruptCause;  // mcause code of the interrupt
    logic                  ToS;             // The trap is taken in S-mode
    logic                  MretTaken;       // MRET commits this cycle
    logic                  SretTaken;       // SRET commits this cycle
    logic                  Retire;          // Instruction retires (minstret)
    logic                  CounterWrite;    // This cycle's CSR instruction writes its CSR

    function automatic logic [DATA_WIDTH-1:0] TrapCause(input traps_t TrapCode);
        case(TrapCode)
            InstructionAddressMisalignedOrUserSoftwareInterrupt: TrapCause = DATA_WIDTH'(0);
            InstructionAccessFaultOrSupervisorSoftwareInterrupt: TrapCause = DATA_WIDTH'(1);
            IllegalInstructionOrHypervisorSoftwareInterrupt: TrapCause = DATA_WIDTH'(2);
            BreakpointOrMachineSoftwareInterrupt: TrapCause = DATA_WIDTH'(3);
            LoadAddressMisalignedOrUserSoftwareInterrupt: TrapCause = DATA_WIDTH'(4);
            LoadAddressFaultOrSupervisorTimerInterrupt: TrapCause = DATA_WIDTH'(5);
            StoreAddressMisalignedOrHyperVisorTimerInterrupt: TrapCause = DATA_WIDTH'(6);
            StoreAddressFaultOrMachineTimerInterrupt: TrapCause = DATA_WIDTH'(7);
            EcallUOrUserExternalInterrupt: TrapCause = DATA_WIDTH'(8);
            EcallSOrSupervisorExternalInterrupt: TrapCause = DATA_WIDTH'(9);
            EcallHOrHypervisorExternalInterrupt: TrapCause = DATA_WIDTH'(10);
            EcallMOrMachineExternalInterrupt: TrapCause = DATA_WIDTH'(11);
            default: TrapCause = DATA_WIDTH'(0);
        endcase
    endfunction:TrapCause

    // ─── Read views ───────────────────────────────────────────────────────────
    always_comb
    begin
        MStatusValue = '0;
        MStatusValue[`MIE] = MStatusMIE;
        MStatusValue[`MPIE] = MStatusMPIE;
        MStatusValue[`MPPE:`MPPS] = MStatusMPP;
        MStatusValue[`FSE:`FSS] = MStatusFS;
        MStatusValue[`MPRV] = MStatusMPRV;
        MStatusValue[`TW] = MStatusTW;
        MStatusValue[`SIE] = MStatusSIE;
        MStatusValue[`SPIE] = MStatusSPIE;
        MStatusValue[`SPP] = MStatusSPP;
        MStatusValue[`TSR] = MStatusTSR;
        MStatusValue = MStatusValue | MSTATUS_UXL64[DATA_WIDTH-1:0] | MSTATUS_SXL64[DATA_WIDTH-1:0];
        MStatusValue[DATA_WIDTH-1] = (MStatusFS == 2'b11);   // SD = (FS == Dirty)
        SstatusValue = MStatusValue & SSTATUS_MASK;

        MidelegMask = '0;
        MidelegMask[`SE_I] = Mideleg[2];
        MidelegMask[`ST_I] = Mideleg[1];
        MidelegMask[`SS_I] = Mideleg[0];

        MieValue = '0;
        MieValue[`ME_I] = MieMEIE;
        MieValue[`MT_I] = MieMTIE;
        MieValue[`MS_I] = MieMSIE;
        MieValue[`SE_I] = MieSEIE;
        MieValue[`ST_I] = MieSTIE;
        MieValue[`SS_I] = MieSSIE;

        MipValue = '0;                              // M bits follow the lines; S bits are software
        MipValue[`ME_I] = ExternalInterrupt;
        MipValue[`MT_I] = TimerInterrupt;
        MipValue[`MS_I] = SoftwareInterrupt;
        MipValue[`SE_I] = MipSeipSw | SExternalInterrupt;
        MipValue[`ST_I] = MipStip;
        MipValue[`SS_I] = MipSsip;
    end

    // ─── CSR read mux ─────────────────────────────────────────────────────────
    always_comb
    begin
        CsrOut = '0;
        CsrExists = 1'b1;
        case(CsrIndex)
            fflags:     CsrOut = DATA_WIDTH'(Fflags);
            frm:        CsrOut = DATA_WIDTH'(Frm);
            fcsr:       CsrOut = DATA_WIDTH'({Frm, Fflags});
            mstatus:    CsrOut = MStatusValue;
            misa:       CsrOut = MISA_VALUE;
            sstatus:    CsrOut = SstatusValue;
            sie:        CsrOut = MieValue & MidelegMask;
            sip:        CsrOut = MipValue & MidelegMask;
            stvec:      CsrOut = Stvec;
            scounteren: CsrOut = DATA_WIDTH'(Scounteren);
            senvcfg,
            satp:       CsrOut = '0;                // read-zero WARL until the MMU (B5)
            sscratch:   CsrOut = Sscratch;
            sepc:       CsrOut = Sepc;
            scause:     CsrOut = Scause;
            stval:      CsrOut = Stval;
            medeleg:    CsrOut = DATA_WIDTH'(Medeleg);
            medelegh:   CsrExists = !IS_RV64;       // RV32 only, reads zero
            mideleg:    CsrOut = MidelegMask;
            mie:        CsrOut = MieValue;
            mtvec:      CsrOut = Mtvec;
            mcounteren: CsrOut = DATA_WIDTH'(Mcounteren);
            menvcfg:    CsrOut = '0;                // nothing to configure yet
            menvcfgh:   CsrExists = !IS_RV64;       // RV32 only, reads zero
            mscratch:   CsrOut = Mscratch;
            mepc:       CsrOut = Mepc;
            mcause:     CsrOut = Mcause;
            mtval:      CsrOut = Mtval;
            mip:        CsrOut = MipValue;
            mcycle,
            cycle:      CsrOut = Mcycle[DATA_WIDTH-1:0];
            minstret,
            instret:    CsrOut = Minstret[DATA_WIDTH-1:0];
            time_csr:   CsrOut = MTime[DATA_WIDTH-1:0];
            timeh_csr:  begin
                            CsrOut = DATA_WIDTH'(MTime[63:32]);
                            CsrExists = !IS_RV64;
                        end
            mvendorid:  CsrOut = MVENDORID_VALUE;
            marchid,
            mimpid,
            mhartid:    CsrOut = '0;
            mstatush:   CsrExists = !IS_RV64;       // RV32 only, reads zero
            mcycleh,
            cycleh:     begin
                            CsrOut = DATA_WIDTH'(Mcycle[63:32]);
                            CsrExists = !IS_RV64;
                        end
            minstreth,
            instreth:   begin
                            CsrOut = DATA_WIDTH'(Minstret[63:32]);
                            CsrExists = !IS_RV64;
                        end
            default:    begin
                            // mhpmcounter3-31 (+h on RV32) and mhpmevent3-31 read zero
                            CsrExists = ((CsrIndex >= 12'hB03) && (CsrIndex <= 12'hB1F)) ||
                                        ((CsrIndex >= 12'h323) && (CsrIndex <= 12'h33F)) ||
                                        (!IS_RV64 && (CsrIndex >= 12'hB83) && (CsrIndex <= 12'hB9F));
                        end
        endcase
    end

    // ─── CSR write data ───────────────────────────────────────────────────────
    always_comb
    begin
        Uimm = DATA_WIDTH'(Rs);
        CsrWrite = 1'b0;
        // csrrs/csrrc on mip modify the software SEIP bit, not the OR with the line
        CsrBase = CsrOut;
        if(CsrIndex == mip)
            CsrBase[`SE_I] = MipSeipSw;
        CsrWriteData = CsrOut;
        case(CsrOperation)
            csrrw:  begin
                        CsrWrite = 1'b1;
                        CsrWriteData = CsrIn;
                    end
            csrrs:  begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrBase | CsrIn;
                    end
            csrrc:  begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrBase & ~CsrIn;
                    end
            csrrwi: begin
                        CsrWrite = 1'b1;
                        CsrWriteData = Uimm;
                    end
            csrrsi: begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrBase | Uimm;
                    end
            csrrci: begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrBase & ~Uimm;
                    end
            default:CsrWrite = 1'b0;
        endcase
    end

    // ─── Trap decision (combinational, same cycle) ───────────────────────────
    always_comb
    begin
        // Privilege-dependent legality (cause 2, mtval 0), folded into CsrIllegal.
        // mcounteren gates S and U, scounteren gates U as well.
        CounterGated = CsrAccess &&
                        (
                        (CsrIndex inside {cycle,cycleh} &&
                            ((PrivMode != MachineMode && !Mcounteren[`CY]) || (PrivMode == UserMode && !Scounteren[`CY]))) ||
                        (CsrIndex inside {time_csr, timeh_csr} &&
                            ((PrivMode != MachineMode && !Mcounteren[`TM]) || (PrivMode == UserMode && !Scounteren[`TM]))) ||
                        (CsrIndex inside {instret,  instreth}  &&
                            ((PrivMode != MachineMode && !Mcounteren[`IR]) || (PrivMode == UserMode && !Scounteren[`IR])))
                        );
        PrivIllegal  = (CsrAccess && (CsrIndex[9:8] > PrivMode)) || 
                        CounterGated ||
                       (mret && (PrivMode != MachineMode)) ||
                       (sret && ((PrivMode == UserMode) || ((PrivMode == SupervisorMode) && MStatusTSR))) ||
                       (Wfi && (PrivMode != MachineMode) && (MStatusTW || PrivMode == UserMode)) ||
                       (FpOp && MStatusFS == 2'b00) ||
                       (CsrAccess && CsrIndex inside {fflags, frm, fcsr} && MStatusFS == 2'b00);
        CsrIllegal   = (CsrAccess && !CsrExists) || PrivIllegal;
        ExceptionValid = (Traps != NoTraps) || CsrIllegal;
        ExceptionCause = CsrIllegal ? DATA_WIDTH'(2) : TrapCause(Traps);

        // Interrupt arbitration: M-targeted group first, then the S-delegated group.
        // M interrupts are always on below M, S interrupts never in M.
        IrqPendM = MipValue & MieValue & ~MidelegMask &
                   {DATA_WIDTH{MStatusMIE || (PrivMode != MachineMode)}};
        IrqPendS = MipValue & MieValue & MidelegMask &
                   {DATA_WIDTH{(PrivMode == UserMode) || (PrivMode == SupervisorMode && MStatusSIE)}};
        IrqSel   = (|IrqPendM) ? IrqPendM : IrqPendS;
        IrqToS   = !(|IrqPendM) && (|IrqPendS);
        InterruptPending = |IrqSel;
        // Priority MEI > MSI > MTI > SEI > SSI > STI inside a group
        if(IrqSel[`ME_I])
            InterruptCause = DATA_WIDTH'(`MACHINE_EXTERNAL_INTERRUPT_CAUSE);
        else if(IrqSel[`MS_I])
            InterruptCause = DATA_WIDTH'(`MACHINE_SOFTWARE_INTERRUPT_CAUSE);
        else if(IrqSel[`MT_I])
            InterruptCause = DATA_WIDTH'(`MACHINE_TIMER_INTERRUPT_CAUSE);
        else if(IrqSel[`SE_I])
            InterruptCause = DATA_WIDTH'(`SE_I);
        else if(IrqSel[`SS_I])
            InterruptCause = DATA_WIDTH'(`SS_I);
        else
            InterruptCause = DATA_WIDTH'(`ST_I);

        // Delegation, never from M
        ToS = (PrivMode != MachineMode) &&
              (InterruptPending ? IrqToS : ((ExceptionCause[4:0] < 5'd20) && Medeleg[ExceptionCause[4:0]]));

        TrapTaken = Commit && (InterruptPending || ExceptionValid);
        MretTaken = Commit && mret && !TrapTaken;
        SretTaken = Commit && sret && !TrapTaken;
        TrapIsSet = TrapTaken || MretTaken || SretTaken;
        Retire    = Commit && !TrapTaken;
        CounterWrite = Commit && !TrapTaken && !mret && CsrAccess && CsrWrite;

        // WFI wakes on any locally pending interrupt, ignoring mstatus.MIE and PrivMode
        WfiWake  = |(MipValue & MieValue);
        WfiStall = WfiWait && !WfiWake;

        CsrOutPC = SretTaken ? Sepc : Mepc;
        if(TrapTaken)
        begin
            // Vectored mode adds 4 * cause for interrupts only
            CsrOutPC = ToS ? {Stvec[DATA_WIDTH-1:2], 2'b00} : {Mtvec[DATA_WIDTH-1:2], 2'b00};
            if(InterruptPending && (ToS ? Stvec[`MTVEC_MODE_START] : Mtvec[`MTVEC_MODE_START]))
                CsrOutPC = CsrOutPC + (InterruptCause << 2);
        end
    end

    // ─── State update ─────────────────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst)
    begin:CSR_File
        if (!rst)
        begin:Reset
            MStatusMIE  <= 1'b0;
            MStatusMPIE <= 1'b0;
            MStatusMPP  <= UserMode;
            MStatusSIE  <= 1'b0;
            MStatusSPIE <= 1'b0;
            MStatusSPP  <= 1'b0;
            MStatusTSR  <= 1'b0;
            MStatusMPRV <= 1'b0;
            MStatusTW   <= 1'b0;
            MStatusFS   <= 2'b00;
            Mcounteren  <= '0;
            Scounteren  <= '0;
            Medeleg     <= '0;
            Mideleg     <= '0;
            PrivMode    <= MachineMode;
            WfiWait     <= 1'b0;
            MieMEIE     <= 1'b0;
            MieMTIE     <= 1'b0;
            MieMSIE     <= 1'b0;
            MieSEIE     <= 1'b0;
            MieSTIE     <= 1'b0;
            MieSSIE     <= 1'b0;
            MipSeipSw   <= 1'b0;
            MipStip     <= 1'b0;
            MipSsip     <= 1'b0;
            Mtvec       <= '0;
            Mscratch    <= '0;
            Mepc        <= '0;
            Mcause      <= '0;
            Mtval       <= '0;
            Stvec       <= '0;
            Sscratch    <= '0;
            Sepc        <= '0;
            Scause      <= '0;
            Stval       <= '0;
            Mcycle      <= '0;
            Minstret    <= '0;
            Fflags      <= '0;
            Frm         <= '0;
        end:Reset
        else
        begin
            // Counters. A CSR write to either half of a counter replaces that
            // cycle's increment (Zicsr: "the write is done instead of the
            // increment"), so the increment is suppressed for both halves.
            if(!(CounterWrite && ((CsrIndex == mcycle) || (CsrIndex == mcycleh))))
                Mcycle <= Mcycle + 1'b1;
            if(Retire && !(CounterWrite && ((CsrIndex == minstret) || (CsrIndex == minstreth))))
                Minstret <= Minstret + 1'b1;

            if(Commit && Wfi && !TrapTaken)
                WfiWait <= 1'b1;
            else if(WfiWake)
                WfiWait <= 1'b0;

            if(Commit && !TrapTaken && FpRegWrite)
                MStatusFS <= 2'b11;

            if(TrapTaken && ToS)
            begin:Trap_Entry_S
                Sepc        <= {PC[DATA_WIDTH-1:2], 2'b00};
                Scause      <= InterruptPending ? {1'b1, InterruptCause[DATA_WIDTH-2:0]}
                                                : ExceptionCause;
                Stval       <= (InterruptPending || CsrIllegal) ? '0 : Address;
                MStatusSPIE <= MStatusSIE;
                MStatusSIE  <= 1'b0;
                MStatusSPP  <= (PrivMode == SupervisorMode);
                PrivMode    <= SupervisorMode;
            end:Trap_Entry_S
            else if(TrapTaken)
            begin:Trap_Entry
                Mepc        <= {PC[DATA_WIDTH-1:2], 2'b00};
                Mcause      <= InterruptPending ? {1'b1, InterruptCause[DATA_WIDTH-2:0]}
                                                : ExceptionCause;
                Mtval       <= (InterruptPending || CsrIllegal) ? '0 : Address;
                MStatusMPIE <= MStatusMIE;
                MStatusMIE  <= 1'b0;
                MStatusMPP  <= PrivMode;
                PrivMode    <= MachineMode;
            end:Trap_Entry
            else if(MretTaken)
            begin:Return_From_Trap
                MStatusMIE  <= MStatusMPIE;
                MStatusMPIE <= 1'b1;
                PrivMode    <= MStatusMPP;
                MStatusMPP  <= UserMode;
                if(MStatusMPP != MachineMode)
                    MStatusMPRV <= 1'b0;
            end:Return_From_Trap
            else if(SretTaken)
            begin:Return_From_S_Trap
                PrivMode    <= MStatusSPP ? SupervisorMode : UserMode;
                MStatusSIE  <= MStatusSPIE;
                MStatusSPIE <= 1'b1;
                MStatusSPP  <= 1'b0;
                MStatusMPRV <= 1'b0;
            end:Return_From_S_Trap
            else if(Commit && CsrAccess && CsrWrite)
            begin:CSR_Access
                case(CsrIndex)
                    fflags:     begin Fflags <= CsrWriteData[4:0]; MStatusFS <= 2'b11; end
                    frm:        begin Frm <= CsrWriteData[2:0]; MStatusFS <= 2'b11; end
                    fcsr:       begin {Frm, Fflags} <= CsrWriteData[7:0]; MStatusFS <= 2'b11; end
                    mstatus:    begin
                                    MStatusMIE  <= CsrWriteData[`MIE];
                                    MStatusMPIE <= CsrWriteData[`MPIE];
                                    MStatusMPP  <= (CsrWriteData[`MPPE:`MPPS] == 2'b11) ? MachineMode :
                                                   (CsrWriteData[`MPPE:`MPPS] == 2'b01) ? SupervisorMode : UserMode;
                                    MStatusMPRV <= CsrWriteData[`MPRV];
                                    MStatusTW   <= CsrWriteData[`TW];
                                    MStatusFS   <= CsrWriteData[`FSE:`FSS];
                                    MStatusSIE  <= CsrWriteData[`SIE];
                                    MStatusSPIE <= CsrWriteData[`SPIE];
                                    MStatusSPP  <= CsrWriteData[`SPP];
                                    MStatusTSR  <= CsrWriteData[`TSR];
                                end
                    sstatus:    begin
                                    MStatusSIE  <= CsrWriteData[`SIE];
                                    MStatusSPIE <= CsrWriteData[`SPIE];
                                    MStatusSPP  <= CsrWriteData[`SPP];
                                    MStatusFS   <= CsrWriteData[`FSE:`FSS];
                                end
                    mie:        begin
                                    MieMEIE <= CsrWriteData[`ME_I];
                                    MieMTIE <= CsrWriteData[`MT_I];
                                    MieMSIE <= CsrWriteData[`MS_I];
                                    MieSEIE <= CsrWriteData[`SE_I];
                                    MieSTIE <= CsrWriteData[`ST_I];
                                    MieSSIE <= CsrWriteData[`SS_I];
                                end
                    sie:        begin       // only the delegated bits change
                                    if(Mideleg[2]) MieSEIE <= CsrWriteData[`SE_I];
                                    if(Mideleg[1]) MieSTIE <= CsrWriteData[`ST_I];
                                    if(Mideleg[0]) MieSSIE <= CsrWriteData[`SS_I];
                                end
                    mip:        begin       // M bits follow the lines
                                    MipSeipSw <= CsrWriteData[`SE_I];
                                    MipStip   <= CsrWriteData[`ST_I];
                                    MipSsip   <= CsrWriteData[`SS_I];
                                end
                    sip:        if(Mideleg[0]) MipSsip <= CsrWriteData[`SS_I];
                    medeleg:    Medeleg <= CsrWriteData[19:0] & MEDELEG_MASK;
                    mideleg:    Mideleg <= {CsrWriteData[`SE_I], CsrWriteData[`ST_I], CsrWriteData[`SS_I]};
                    stvec:      Stvec <= {CsrWriteData[DATA_WIDTH-1:2], 1'b0, CsrWriteData[0]};
                    scounteren: Scounteren <= CsrWriteData[2:0];
                    sscratch:   Sscratch <= CsrWriteData;
                    sepc:       Sepc <= {CsrWriteData[DATA_WIDTH-1:2], 2'b00};
                    scause:     Scause <= CsrWriteData;
                    stval:      Stval <= CsrWriteData;
                    mtvec:      Mtvec <= {CsrWriteData[DATA_WIDTH-1:2], 1'b0, CsrWriteData[0]};
                    mcounteren: Mcounteren <= CsrWriteData[2:0];
                    mscratch:   Mscratch <= CsrWriteData;
                    mepc:       Mepc <= {CsrWriteData[DATA_WIDTH-1:2], 2'b00};
                    mcause:     Mcause <= CsrWriteData;
                    mtval:      Mtval <= CsrWriteData;
                    mcycle:     Mcycle[DATA_WIDTH-1:0] <= CsrWriteData;
                    minstret:   Minstret[DATA_WIDTH-1:0] <= CsrWriteData;
                    mcycleh:    if(!IS_RV64) Mcycle[63:32] <= CsrWriteData[31:0];
                    minstreth:  if(!IS_RV64) Minstret[63:32] <= CsrWriteData[31:0];
                    // misa (WARL, fixed), mstatush, medelegh, menvcfg(h), senvcfg, satp
                    // and the mhpm* registers ignore writes.
                    // Writes to the read-only space trap in decode.
                    default:    ;
                endcase
            end:CSR_Access
        end
    end:CSR_File

    assign RoundingMode = round_mode_t'(Frm);

endmodule
