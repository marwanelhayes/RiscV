import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface wb_wr 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    input clk,
    input rst,
    input PCSrcE,
    input StallF,
    input [ADDR_WIDTH-1:0] PCPlus4F,
    input [ADDR_WIDTH-1:0] PCBranchE,
    input [DATA_WIDTH-1:0] ALUOutW,
    input [DATA_WIDTH-1:0] ReadDataW,
    input selector_t SelectorW,
    input logic [ADDR_WIDTH-1:0] CsrOutPC,
    input logic TrapIsSet,
    input [ADDR_WIDTH-1:0] PCPlus4W,
    input [DATA_WIDTH-1:0] CsrOutW,
    
    input logic [DATA_WIDTH-1:0] ResultW,
    input logic [ADDR_WIDTH-1:0] PCF
);


    writeback_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) wb_intf (
        .clk(clk)
    );
    always_comb
    begin
        wb_intf.rst = rst;
        wb_intf.PCSrcE = PCSrcE;
        wb_intf.StallF = StallF;
        wb_intf.PCPlus4F = PCPlus4F;
        wb_intf.PCBranchE = PCBranchE;
        wb_intf.ALUOutW = ALUOutW;
        wb_intf.ReadDataW = ReadDataW;
        wb_intf.SelectorW = SelectorW;
        wb_intf.CsrOutPC = CsrOutPC;
        wb_intf.TrapIsSet = TrapIsSet;
        wb_intf.CsrOutW = CsrOutW;
        wb_intf.PCPlus4W = PCPlus4W;
    
        wb_intf.ResultW = ResultW;
        wb_intf.PCF = PCF;

    end
    
    /*
    assign wb_intf.rst = rst;
    assign wb_intf.PCSrcE = PCSrcE;
    assign wb_intf.StallF = StallF;
    assign wb_intf.PCPlus4F = PCPlus4F;
    assign wb_intf.PCBranchE = PCBranchE;
    assign wb_intf.ALUOutW = ALUOutW;
    assign wb_intf.ReadDataW = ReadDataW;
    assign wb_intf.SelectorW = SelectorW;
    assign wb_intf.CsrOutPC = CsrOutPC;
    assign wb_intf.TrapIsSet = TrapIsSet;
    assign wb_intf.CsrOutW = CsrOutW;
    assign wb_intf.PCPlus4W = PCPlus4W;
    
    assign wb_intf.ResultW = ResultW;
    assign wb_intf.PCF = PCF;
*/
    initial
    begin
        uvm_config_db #(virtual writeback_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)))::set(null,"","INTF",wb_intf.TEST);
    end
endinterface