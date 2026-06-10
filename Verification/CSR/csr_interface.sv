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
    logic [FINAL_ADDR_WIDTH-1:0]  PC;
    logic [FINAL_ADDR_WIDTH-1:0]  Address;
    logic                         CsrAccess;
    logic [FINAL_DATA_WIDTH-1:0]  CsrIn;
    logic                         TimerInterrupt;
    logic                         ExternalInterrupt;
    logic                         SoftwareInterrupt;
    csr_index_t                   CsrIndex;

    logic [FINAL_ADDR_WIDTH-1:0]  CsrOutPC;
    logic [FINAL_DATA_WIDTH-1:0]  CsrOut;
    logic                         TrapIsSet;
    round_mode_t                  RoundingMode;

    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst, CsrOperation, Rs, Traps, mret, PC, Address, CsrAccess, CsrIn;
        output TimerInterrupt, ExternalInterrupt, SoftwareInterrupt, CsrIndex;
        input  CsrOutPC, CsrOut, TrapIsSet, RoundingMode;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;
        input rst, CsrOperation, Rs, Traps, mret, PC, Address, CsrAccess, CsrIn;
        input TimerInterrupt, ExternalInterrupt, SoftwareInterrupt, CsrIndex;
        input CsrOutPC, CsrOut, TrapIsSet, RoundingMode;
    endclocking:pck

    task initialize ();
        rst               <= 1'b0;
        CsrOperation      <= csrrw;
        Rs                <= gpr_t'(0);
        Traps             <= NoTraps;
        mret              <= 1'b0;
        PC                <= '0;
        Address           <= '0;
        CsrAccess         <= 1'b0;
        CsrIn             <= '0;
        TimerInterrupt    <= 1'b0;
        ExternalInterrupt <= 1'b0;
        SoftwareInterrupt <= 1'b0;
        CsrIndex          <= mstatus;
        repeat(5) @(posedge clk);
        rst <= 1'b1;
    endtask:initialize

    task drv2intf (csr_item drv);
        @(mck);
        mck.rst               <= drv.rst;
        mck.CsrOperation      <= drv.CsrOperation;
        mck.Rs                <= drv.Rs;
        mck.Traps             <= drv.Traps;
        mck.mret              <= drv.mret;
        mck.PC                <= drv.PC;
        mck.Address           <= drv.Address;
        mck.CsrAccess         <= drv.CsrAccess;
        mck.CsrIn             <= drv.CsrIn;
        mck.TimerInterrupt    <= drv.TimerInterrupt;
        mck.ExternalInterrupt <= drv.ExternalInterrupt;
        mck.SoftwareInterrupt <= drv.SoftwareInterrupt;
        mck.CsrIndex          <= drv.CsrIndex;
    endtask:drv2intf

    task intf2mon (csr_item mon);
        @(pck);
        mon.rst               = pck.rst;
        mon.CsrOperation      = pck.CsrOperation;
        mon.Rs                = pck.Rs;
        mon.Traps             = pck.Traps;
        mon.mret              = pck.mret;
        mon.PC                = pck.PC;
        mon.Address           = pck.Address;
        mon.CsrAccess         = pck.CsrAccess;
        mon.CsrIn             = pck.CsrIn;
        mon.TimerInterrupt    = pck.TimerInterrupt;
        mon.ExternalInterrupt = pck.ExternalInterrupt;
        mon.SoftwareInterrupt = pck.SoftwareInterrupt;
        mon.CsrIndex          = pck.CsrIndex;
        mon.CsrOutPC          = pck.CsrOutPC;
        mon.CsrOut            = pck.CsrOut;
        mon.TrapIsSet         = pck.TrapIsSet;
        mon.RoundingMode      = pck.RoundingMode;
    endtask:intf2mon

    modport RISC (clocking pck);

endinterface: csr_interface
