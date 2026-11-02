// =============================================================================
// csr_file.sv
// -----------------------------------------------------------------------------
// Control and Status Register (CSR) file for RISC-V processor (M-mode only).
//
// Responsibilities:
//   - Hold the machine-mode CSRs as explicit registers (no CSR array)
//   - Read any implemented CSR combinationally; flag unknown CSRs as illegal
//   - Take traps (exceptions and interrupts) and MRET in the same cycle the
//     instruction is in EX, so the trapping instruction never commits
//   - Process CSR read/write operations (CSRRW, CSRRS, CSRRC, etc.)
//   - Count cycles and retired instructions (64-bit on RV32 and RV64)
//   - Provide rounding mode for FPU operations
//
// Every state update happens only on Commit (a valid EX instruction that
// advances this cycle), so a stalled pipeline never repeats a side effect.
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
    input [DATA_WIDTH-1:0] PC,            // PC of the EX instruction (for mepc)
    input [DATA_WIDTH-1:0] Address,       // Trap value for the exception (for mtval)
    input CsrAccess,                      // CSR access enable
    input [DATA_WIDTH-1:0] CsrIn,         // CSR write data (forwarded rs1)
    input Commit,                         // Valid EX instruction that advances this cycle

    // ─── Interrupt inputs ─────────────────────────────────────────────────────
    input TimerInterrupt,                 // Timer interrupt
    input ExternalInterrupt,              // External hardware interrupt
    input SoftwareInterrupt,              // Software interrupt

    // ─── CSR register index ───────────────────────────────────────────────────
    input csr_index_t CsrIndex,           // CSR address

    // ─── Outputs ───────────────────────────────────────────────────────────────
    output logic [DATA_WIDTH-1:0] CsrOutPC,   // Redirect target: trap vector or mepc
    output logic [DATA_WIDTH-1:0] CsrOut,     // CSR read data
    output logic TrapIsSet,                   // Redirect now: trap taken or MRET
    output logic TrapTaken,                   // Exception or interrupt taken: squash EX
    output round_mode_t RoundingMode          // FPU rounding mode
);

    localparam bit IS_RV64 = (DATA_WIDTH == 64);
    localparam logic [1:0] MXL = IS_RV64 ? 2'd2 : 2'd1;
    localparam logic [DATA_WIDTH-1:0] MISA_VALUE = {MXL, {(DATA_WIDTH-2){1'b0}}}
                                                 | (DATA_WIDTH'(1) << `MISA_I)
                                                 | (DATA_WIDTH'(1) << `MISA_M)
                                                 | (DATA_WIDTH'(1) << `MISA_F);
    localparam logic [DATA_WIDTH-1:0] MVENDORID_VALUE = DATA_WIDTH'(32'h48_41_4E_4F);

    // ─── Architectural state ──────────────────────────────────────────────────
    logic                  MStatusMIE;      // mstatus.MIE
    logic                  MStatusMPIE;     // mstatus.MPIE
    logic                  MieMEIE;         // mie.MEIE
    logic                  MieMTIE;         // mie.MTIE
    logic                  MieMSIE;         // mie.MSIE
    logic [DATA_WIDTH-1:0] Mtvec;           // mtvec (bit 1 always 0)
    logic [DATA_WIDTH-1:0] Mscratch;        // mscratch
    logic [DATA_WIDTH-1:0] Mepc;            // mepc (bits 1:0 always 0)
    logic [DATA_WIDTH-1:0] Mcause;          // mcause
    logic [DATA_WIDTH-1:0] Mtval;           // mtval
    logic [63:0]           Mcycle;          // mcycle (+ mcycleh on RV32)
    logic [63:0]           Minstret;        // minstret (+ minstreth on RV32)
    logic [4:0]            Fflags;          // fflags
    logic [2:0]            Frm;             // frm

    // ─── Internal wires ───────────────────────────────────────────────────────
    logic [DATA_WIDTH-1:0] MStatusValue;    // mstatus as read
    logic [DATA_WIDTH-1:0] MieValue;        // mie as read
    logic [DATA_WIDTH-1:0] MipValue;        // mip as read
    logic                  CsrExists;       // CsrIndex names an implemented CSR
    logic                  CsrIllegal;      // CSR access to an unknown CSR
    logic                  CsrWrite;        // This CSR instruction writes its CSR
    logic [DATA_WIDTH-1:0] CsrWriteData;    // Value written by the CSR instruction
    logic [DATA_WIDTH-1:0] Uimm;            // Zero-extended immediate operand
    logic                  ExceptionValid;  // Synchronous exception of the EX instruction
    logic [DATA_WIDTH-1:0] ExceptionCause;  // mcause code of the exception
    logic                  InterruptPending;// Enabled interrupt waiting
    logic [DATA_WIDTH-1:0] InterruptCause;  // mcause code of the interrupt
    logic                  MretTaken;       // MRET commits this cycle
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
        MStatusValue[`MPPE:`MPPS] = 2'b11;          // M-only: MPP is always M
        MStatusValue[`FSE:`FSS] = 2'b11;            // FPU always on: FS = Dirty
        MStatusValue[DATA_WIDTH-1] = 1'b1;          // SD = (FS == Dirty)

        MieValue = '0;
        MieValue[`ME_I] = MieMEIE;
        MieValue[`MT_I] = MieMTIE;
        MieValue[`MS_I] = MieMSIE;

        MipValue = '0;                              // Pending bits follow the lines
        MipValue[`ME_I] = ExternalInterrupt;
        MipValue[`MT_I] = TimerInterrupt;
        MipValue[`MS_I] = SoftwareInterrupt;
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
            medeleg:    CsrOut = '0;                // M-only: nothing to delegate
            mideleg:    CsrOut = '0;
            mie:        CsrOut = MieValue;
            mtvec:      CsrOut = Mtvec;
            mscratch:   CsrOut = Mscratch;
            mepc:       CsrOut = Mepc;
            mcause:     CsrOut = Mcause;
            mtval:      CsrOut = Mtval;
            mip:        CsrOut = MipValue;
            mcycle,
            cycle:      CsrOut = Mcycle[DATA_WIDTH-1:0];
            minstret,
            instret:    CsrOut = Minstret[DATA_WIDTH-1:0];
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
        CsrWriteData = CsrOut;
        case(CsrOperation)
            csrrw:  begin
                        CsrWrite = 1'b1;
                        CsrWriteData = CsrIn;
                    end
            csrrs:  begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrOut | CsrIn;
                    end
            csrrc:  begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrOut & ~CsrIn;
                    end
            csrrwi: begin
                        CsrWrite = 1'b1;
                        CsrWriteData = Uimm;
                    end
            csrrsi: begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrOut | Uimm;
                    end
            csrrci: begin
                        CsrWrite = (Rs != zero);
                        CsrWriteData = CsrOut & ~Uimm;
                    end
            default:CsrWrite = 1'b0;
        endcase
    end

    // ─── Trap decision (combinational, same cycle) ───────────────────────────
    always_comb
    begin
        CsrIllegal = CsrAccess && !CsrExists;
        ExceptionValid = (Traps != NoTraps) || CsrIllegal;
        ExceptionCause = CsrIllegal ? DATA_WIDTH'(2) : TrapCause(Traps);

        // Priority MEI > MSI > MTI, gated by mstatus.MIE
        InterruptPending = MStatusMIE && ((MieMEIE && ExternalInterrupt) ||
                                          (MieMSIE && SoftwareInterrupt) ||
                                          (MieMTIE && TimerInterrupt));
        if(MieMEIE && ExternalInterrupt)
            InterruptCause = DATA_WIDTH'(`MACHINE_EXTERNAL_INTERRUPT_CAUSE);
        else if(MieMSIE && SoftwareInterrupt)
            InterruptCause = DATA_WIDTH'(`MACHINE_SOFTWARE_INTERRUPT_CAUSE);
        else
            InterruptCause = DATA_WIDTH'(`MACHINE_TIMER_INTERRUPT_CAUSE);

        TrapTaken = Commit && (InterruptPending || ExceptionValid);
        MretTaken = Commit && mret && !TrapTaken;
        TrapIsSet = TrapTaken || MretTaken;
        Retire    = Commit && !TrapTaken;
        CounterWrite = Commit && !TrapTaken && !mret && CsrAccess && CsrWrite;

        CsrOutPC = Mepc;
        if(TrapTaken)
        begin
            CsrOutPC = {Mtvec[DATA_WIDTH-1:2], 2'b00};
            if(InterruptPending && (Mtvec[`MTVEC_MODE_END:`MTVEC_MODE_START] == `MTVEC_VECTORED))
                CsrOutPC = {Mtvec[DATA_WIDTH-1:2], 2'b00} + (InterruptCause << 2);
        end
    end

    // ─── State update ─────────────────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst)
    begin:CSR_File
        if (!rst)
        begin:Reset
            MStatusMIE  <= 1'b0;
            MStatusMPIE <= 1'b0;
            MieMEIE     <= 1'b0;
            MieMTIE     <= 1'b0;
            MieMSIE     <= 1'b0;
            Mtvec       <= '0;
            Mscratch    <= '0;
            Mepc        <= '0;
            Mcause      <= '0;
            Mtval       <= '0;
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

            if(TrapTaken)
            begin:Trap_Entry
                Mepc        <= {PC[DATA_WIDTH-1:2], 2'b00};
                Mcause      <= InterruptPending ? {1'b1, InterruptCause[DATA_WIDTH-2:0]}
                                                : ExceptionCause;
                Mtval       <= (InterruptPending || CsrIllegal) ? '0 : Address;
                MStatusMPIE <= MStatusMIE;
                MStatusMIE  <= 1'b0;
            end:Trap_Entry
            else if(MretTaken)
            begin:Return_From_Trap
                MStatusMIE  <= MStatusMPIE;
                MStatusMPIE <= 1'b1;
            end:Return_From_Trap
            else if(Commit && CsrAccess && CsrWrite)
            begin:CSR_Access
                case(CsrIndex)
                    fflags:     Fflags <= CsrWriteData[4:0];
                    frm:        Frm <= CsrWriteData[2:0];
                    fcsr:       {Frm, Fflags} <= CsrWriteData[7:0];
                    mstatus:    begin
                                    MStatusMIE  <= CsrWriteData[`MIE];
                                    MStatusMPIE <= CsrWriteData[`MPIE];
                                end
                    mie:        begin
                                    MieMEIE <= CsrWriteData[`ME_I];
                                    MieMTIE <= CsrWriteData[`MT_I];
                                    MieMSIE <= CsrWriteData[`MS_I];
                                end
                    mtvec:      Mtvec <= {CsrWriteData[DATA_WIDTH-1:2], 1'b0, CsrWriteData[0]};
                    mscratch:   Mscratch <= CsrWriteData;
                    mepc:       Mepc <= {CsrWriteData[DATA_WIDTH-1:2], 2'b00};
                    mcause:     Mcause <= CsrWriteData;
                    mtval:      Mtval <= CsrWriteData;
                    mcycle:     Mcycle[DATA_WIDTH-1:0] <= CsrWriteData;
                    minstret:   Minstret[DATA_WIDTH-1:0] <= CsrWriteData;
                    mcycleh:    if(!IS_RV64) Mcycle[63:32] <= CsrWriteData[31:0];
                    minstreth:  if(!IS_RV64) Minstret[63:32] <= CsrWriteData[31:0];
                    // misa (WARL, fixed), mip (driven by the lines), medeleg,
                    // mideleg, mstatush and the mhpm* registers ignore writes.
                    // Writes to the read-only space trap in decode.
                    default:    ;
                endcase
            end:CSR_Access
        end
    end:CSR_File

    assign RoundingMode = round_mode_t'(Frm);

endmodule
