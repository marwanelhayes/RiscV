import shared_pkg::*;
import csr_item_pkg::*;

interface csr_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    logic rst;
    csr_t CsrOperation;
    gpr_t Rs;
    traps_t Traps;
    logic mret;
    logic [FINAL_ADDR_WIDTH-1:0] PC;
    logic [FINAL_ADDR_WIDTH-1:0] Address;
    logic CsrAccess;
    logic [FINAL_DATA_WIDTH-1:0] CsrIn;
    logic TimerInterrupt;
    logic ExternalInterrupt;
    logic SoftwareInterrupt;
    csr_index_t CsrIndex;

    logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC;
    logic [FINAL_DATA_WIDTH-1:0] CsrOut;
    logic TrapIsSet;
    round_mode_t RoundingMode;

    clocking cb @(posedge clk);
        default input #0;

        input #CLK rst;
        input #CLK CsrOperation;
        input #CLK Rs;
        input #CLK Traps;
        input #CLK mret;
        input #CLK PC;
        input #CLK Address;
        input #CLK CsrAccess;
        input #CLK CsrIn;
        input #CLK TimerInterrupt;
        input #CLK ExternalInterrupt;
        input #CLK SoftwareInterrupt;
        input #CLK CsrIndex;

        input CsrOutPC;
        input CsrOut;
        input TrapIsSet;
        input #1step RoundingMode;
    endclocking:cb

    task initialize ();
        rst <= 'b0;
        CsrOperation <= csrrw;
        Rs <= gpr_t'(0);
        Traps <= NoTraps;
        mret <= 'b0;
        PC <= 'b0;
        Address <= 'b0;
        CsrAccess <= 'b0;
        CsrIn <= 'b0;
        TimerInterrupt <= 'b0;
        ExternalInterrupt <= 'b0;
        SoftwareInterrupt <= 'b0;
        CsrIndex <= mstatus;
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (csr_item drv);
        @(cb);
        CsrOperation <= drv.CsrOperation;
        Rs <= drv.Rs;
        Traps <= drv.Traps;
        mret <= drv.mret;
        PC <= drv.PC;
        Address <= drv.Address;
        CsrAccess <= drv.CsrAccess;
        CsrIn <= drv.CsrIn;
        TimerInterrupt <= drv.TimerInterrupt;
        ExternalInterrupt <= drv.ExternalInterrupt;
        SoftwareInterrupt <= drv.SoftwareInterrupt;
        CsrIndex <= drv.CsrIndex;
        #CLK rst <= drv.rst;
    endtask:drv2intf

    task intf2mon (csr_item mon);
        @(cb);
        mon.rst = cb.rst;
        mon.CsrOperation = cb.CsrOperation;
        mon.Rs = cb.Rs;
        mon.Traps = cb.Traps;
        mon.mret = cb.mret;
        mon.PC = cb.PC;
        mon.Address = cb.Address;
        mon.CsrAccess = cb.CsrAccess;
        mon.CsrIn = cb.CsrIn;
        mon.TimerInterrupt = cb.TimerInterrupt;
        mon.ExternalInterrupt = cb.ExternalInterrupt;
        mon.SoftwareInterrupt = cb.SoftwareInterrupt;
        mon.CsrIndex = cb.CsrIndex;

        mon.CsrOutPC = cb.CsrOutPC;
        mon.CsrOut = cb.CsrOut;
        mon.TrapIsSet = cb.TrapIsSet;
        mon.RoundingMode = cb.RoundingMode;
    endtask:intf2mon

    modport DUT
    (
        input clk,
        rst,
        CsrOperation,
        Rs,
        Traps,
        mret,
        PC,
        Address,
        CsrAccess,
        CsrIn,
        TimerInterrupt,
        ExternalInterrupt,
        SoftwareInterrupt,
        CsrIndex,

        output CsrOutPC,
        CsrOut,
        TrapIsSet,
        RoundingMode
    );

    modport TEST (clocking cb);
endinterface: csr_interface
