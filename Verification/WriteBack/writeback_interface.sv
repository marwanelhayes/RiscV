import shared_pkg::*;
import writeback_item_pkg::*;
interface writeback_interface 
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    
    logic rst;
    logic PCSrcE;
    logic StallF;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F;
    logic [FINAL_ADDR_WIDTH-1:0] PCBranchE;
    logic [FINAL_DATA_WIDTH-1:0] ALUOutW;
    logic signed [FINAL_DATA_WIDTH-1:0] ReadDataW;
    selector_t SelectorW;
    logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC;
    logic TrapIsSet;
    logic [FINAL_DATA_WIDTH-1:0] CsrOutW;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4W;
    
    logic [FINAL_DATA_WIDTH-1:0] ResultW;
    logic [FINAL_ADDR_WIDTH-1:0] PCF;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking mck @(posedge clk);
        default input #1step output #CLK; 
        //default output #CLK;
        output #CLK rst;
        output #CLK PCSrcE;
        output #CLK StallF;
        output #CLK PCPlus4F;
        output #CLK PCBranchE;
        output #CLK ALUOutW;
        output #CLK SelectorW;
        output #CLK ReadDataW;
        output #CLK CsrOutPC;
        output #CLK TrapIsSet;
        output #CLK CsrOutW;
        output #CLK PCPlus4W;

        input PCF;
        input ResultW;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step; 
        input rst;
        input PCSrcE;
        input StallF;
        input PCPlus4F;
        input PCBranchE;
        input ALUOutW;
        input SelectorW;
        input ReadDataW;
        input CsrOutPC;
        input TrapIsSet;
        input CsrOutW;
        input PCPlus4W;

        input PCF;
        input ResultW;
    
    endclocking:pck

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
            @(mck);
        end
    endtask:initialize



    task drv2intf (writeback_item drv);
        @(mck);
        mck.rst <= drv.rst;
        mck.PCSrcE <= drv.PCSrcE;
        mck.StallF <= drv.StallF;
        mck.PCPlus4F <= drv.PCPlus4F;
        mck.PCBranchE <= drv.PCBranchE;
        mck.ALUOutW <= drv.ALUOutW;
        mck.SelectorW <= drv.SelectorW;
        mck.CsrOutW <= drv.CsrOutW;
        mck.PCPlus4W <= drv.PCPlus4W;
        mck.ReadDataW <= drv.ReadDataW;
        mck.TrapIsSet <= drv.TrapIsSet;
        mck.CsrOutPC <= drv.CsrOutPC;
    endtask:drv2intf

    task intf2mon (writeback_item mon);
        @(pck);
        mon.rst = pck.rst;
        mon.StallF = pck.StallF;    
        mon.PCPlus4F = pck.PCPlus4F;
        mon.PCBranchE = pck.PCBranchE;
        mon.ALUOutW = pck.ALUOutW;
        mon.SelectorW = pck.SelectorW;
        mon.ReadDataW = pck.ReadDataW;
        mon.PCSrcE = pck.PCSrcE;
        mon.CsrOutW = pck.CsrOutW;
        mon.PCPlus4W = pck.PCPlus4W;
        mon.TrapIsSet = pck.TrapIsSet;
        mon.CsrOutPC = pck.CsrOutPC;

        mon.ResultW = pck.ResultW;
        mon.PCF = pck.PCF;

    endtask:intf2mon

    modport RISC (clocking pck); 
endinterface: writeback_interface