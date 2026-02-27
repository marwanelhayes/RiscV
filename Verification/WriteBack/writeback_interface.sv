import shared_pkg::*;
import writeback_item_pkg::*;
interface writeback_interface 
#(
    parameter CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    
    logic rst;
    logic PCSrcE;
    logic StallF;
    logic [ADDR_WIDTH-1:0] PCPlus4F;
    logic [ADDR_WIDTH-1:0] PCBranchE;
    logic [DATA_WIDTH-1:0] ALUOutW;
    logic signed [DATA_WIDTH-1:0] ReadDataW;
    selector_t SelectorW;
    logic [ADDR_WIDTH-1:0] CsrOutPC;
    logic TrapIsSet;
    logic [DATA_WIDTH-1:0] CsrOutW;
    logic [ADDR_WIDTH-1:0] PCPlus4W;
    
    logic [DATA_WIDTH-1:0] ResultW;
    logic [ADDR_WIDTH-1:0] PCF;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        //default output #CLK;
        input #CLK rst;
        input #CLK PCSrcE;
        input #CLK StallF;
        input #CLK PCPlus4F;
        input #CLK PCBranchE;
        input #CLK ALUOutW;
        input #CLK SelectorW;
        input #CLK ReadDataW;
        input #CLK CsrOutPC;
        input #CLK TrapIsSet;
        input #CLK CsrOutW;
        input #CLK PCPlus4W;

        input PCF;
        input #1step ResultW;
    
    endclocking:cb

    task initialize;
        rst = 0;
        PCSrcE <= 0;
        StallF <= 0;
        PCPlus4F <= 0;
        PCBranchE <= 0;
        ALUOutW <= 0;
        SelectorW <= ALUToReg;
        CsrOutW <= 0;
        PCPlus4W <= 0;
        TrapIsSet <= 0;
        CsrOutPC <= 0;
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (writeback_item #(DATA_WIDTH,ADDR_WIDTH) drv);
        @(cb);
        rst <= drv.rst;
        PCSrcE <= drv.PCSrcE;
        StallF <= drv.StallF;
        PCPlus4F <= drv.PCPlus4F;
        PCBranchE <= drv.PCBranchE;
        ALUOutW <= drv.ALUOutW;
        SelectorW <= drv.SelectorW;
        CsrOutW <= drv.CsrOutW;
        PCPlus4W <= drv.PCPlus4W;
        ReadDataW <= drv.ReadDataW;
        TrapIsSet <= drv.TrapIsSet;
        CsrOutPC <= drv.CsrOutPC;
    endtask:drv2intf

    task intf2mon (writeback_item #(DATA_WIDTH,ADDR_WIDTH) mon);
        @(cb);
        mon.rst = cb.rst;
        mon.StallF = cb.StallF;    
        mon.PCPlus4F = cb.PCPlus4F;
        mon.PCBranchE = cb.PCBranchE;
        mon.ALUOutW = cb.ALUOutW;
        mon.SelectorW = cb.SelectorW;
        mon.ReadDataW = cb.ReadDataW;
        mon.PCSrcE = cb.PCSrcE;
        mon.CsrOutW = cb.CsrOutW;
        mon.PCPlus4W = cb.PCPlus4W;
        mon.TrapIsSet = cb.TrapIsSet;
        mon.CsrOutPC = cb.CsrOutPC;

        mon.ResultW = cb.ResultW;
        mon.PCF = cb.PCF;

    endtask:intf2mon

    modport DUT 
    (
        input clk, 
        rst, 
        PCSrcE, 
        StallF, 
        PCPlus4F, 
        PCBranchE, 
        ALUOutW, 
        SelectorW,
        ReadDataW,
        CsrOutW,
        PCPlus4W,
        TrapIsSet,
        CsrOutPC,
        output PCF, 
        ResultW
    );

    modport TEST (clocking cb); 
endinterface: writeback_interface