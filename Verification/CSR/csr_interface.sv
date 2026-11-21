// =============================================================================
// csr_interface.sv
// -----------------------------------------------------------------------------
// CSR verification interface. mck=driver, pck=monitor, TEST=verif modport.
// =============================================================================
import shared_pkg::*;
import csr_item_pkg::*;

interface csr_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    logic                         rst;
    csr_t                         CsrOperation;
    gpr_t                         Rs;
    traps_t                       Traps;
    logic                         mret;
    logic                         sret;
    logic [FINAL_DATA_WIDTH-1:0]  PC;
    logic [FINAL_DATA_WIDTH-1:0]  Address;
    logic                         CsrAccess;
    logic [FINAL_DATA_WIDTH-1:0]  CsrIn;
    logic                         Commit;
    logic                         Wfi;
    logic                         FpOp;
    logic                         FpRegWrite;
    logic [63:0]                  MTime;
    logic                         TimerInterrupt;
    logic                         ExternalInterrupt;
    logic                         SoftwareInterrupt;
    logic                         SExternalInterrupt;
    csr_index_t                   CsrIndex;
    logic [FINAL_DATA_WIDTH-1:0]  CsrOutPC;
    logic [FINAL_DATA_WIDTH-1:0]  CsrOut;
    logic                         TrapIsSet;
    logic                         TrapTaken;
    round_mode_t                  RoundingMode;
    priv_mode_t                   PrivMode;
    logic                         WfiStall;

    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst, CsrOperation, Rs, Traps, mret, sret, PC, Address, CsrAccess, CsrIn, Commit, Wfi, FpOp, FpRegWrite, MTime, TimerInterrupt, ExternalInterrupt, SoftwareInterrupt, SExternalInterrupt, CsrIndex;
        input  CsrOutPC, CsrOut, TrapIsSet, TrapTaken, RoundingMode, PrivMode, WfiStall;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;
        input rst, CsrOperation, Rs, Traps, mret, sret, PC, Address, CsrAccess, CsrIn, Commit, Wfi, FpOp, FpRegWrite, MTime, TimerInterrupt, ExternalInterrupt, SoftwareInterrupt, SExternalInterrupt, CsrIndex, CsrOutPC, CsrOut, TrapIsSet, TrapTaken, RoundingMode, PrivMode, WfiStall;
    endclocking:pck

    task initialize ();
        rst <= 1'b0;
        CsrOperation <= csrrw;
        Rs <= zero;
        Traps <= NoTraps;
        mret <= 1'b0;
        sret <= 1'b0;
        PC <= '0;
        Address <= '0;
        CsrAccess <= 1'b0;
        CsrIn <= '0;
        Commit <= 1'b0;
        Wfi <= 1'b0;
        FpOp <= 1'b0;
        FpRegWrite <= 1'b0;
        MTime <= '0;
        TimerInterrupt <= 1'b0;
        ExternalInterrupt <= 1'b0;
        SoftwareInterrupt <= 1'b0;
        SExternalInterrupt <= 1'b0;
        CsrIndex <= mstatus;
        repeat(5) @(posedge clk);
        rst <= 1'b1;
    endtask:initialize

    task drv2intf (csr_item drv);
        @(mck);
        mck.rst <= drv.rst;
        mck.CsrOperation <= drv.CsrOperation;
        mck.Rs <= drv.Rs;
        mck.Traps <= drv.Traps;
        mck.mret <= drv.mret;
        mck.sret <= drv.sret;
        mck.PC <= drv.PC;
        mck.Address <= drv.Address;
        mck.CsrAccess <= drv.CsrAccess;
        mck.CsrIn <= drv.CsrIn;
        mck.Commit <= drv.Commit;
        mck.Wfi <= drv.Wfi;
        mck.FpOp <= drv.FpOp;
        mck.FpRegWrite <= drv.FpRegWrite;
        mck.MTime <= drv.MTime;
        mck.TimerInterrupt <= drv.TimerInterrupt;
        mck.ExternalInterrupt <= drv.ExternalInterrupt;
        mck.SoftwareInterrupt <= drv.SoftwareInterrupt;
        mck.SExternalInterrupt <= drv.SExternalInterrupt;
        mck.CsrIndex <= drv.CsrIndex;
    endtask:drv2intf

    task intf2mon (csr_item mon);
        @(pck);
        mon.rst = pck.rst;
        mon.CsrOperation = pck.CsrOperation;
        mon.Rs = pck.Rs;
        mon.Traps = pck.Traps;
        mon.mret = pck.mret;
        mon.sret = pck.sret;
        mon.PC = pck.PC;
        mon.Address = pck.Address;
        mon.CsrAccess = pck.CsrAccess;
        mon.CsrIn = pck.CsrIn;
        mon.Commit = pck.Commit;
        mon.Wfi = pck.Wfi;
        mon.FpOp = pck.FpOp;
        mon.FpRegWrite = pck.FpRegWrite;
        mon.MTime = pck.MTime;
        mon.TimerInterrupt = pck.TimerInterrupt;
        mon.ExternalInterrupt = pck.ExternalInterrupt;
        mon.SoftwareInterrupt = pck.SoftwareInterrupt;
        mon.SExternalInterrupt = pck.SExternalInterrupt;
        mon.CsrIndex = pck.CsrIndex;
        mon.CsrOutPC = pck.CsrOutPC;
        mon.CsrOut = pck.CsrOut;
        mon.TrapIsSet = pck.TrapIsSet;
        mon.TrapTaken = pck.TrapTaken;
        mon.RoundingMode = pck.RoundingMode;
        mon.PrivMode = pck.PrivMode;
        mon.WfiStall = pck.WfiStall;
    endtask:intf2mon

    modport TEST (clocking mck, clocking pck, output rst);

endinterface:csr_interface
