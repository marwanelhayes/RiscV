import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface wb_wr 
(
    input clk,
    input rst,
    input PCSrcE,
    input StallF,
    input [FINAL_ADDR_WIDTH-1:0] PCPlus4F,
    input [FINAL_ADDR_WIDTH-1:0] PCBranchE,
    input [FINAL_DATA_WIDTH-1:0] ALUOutW,
    input [FINAL_DATA_WIDTH-1:0] ReadDataW,
    input selector_t SelectorW,
    input logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC,
    input logic TrapIsSet,
    input [FINAL_ADDR_WIDTH-1:0] PCPlus4W,
    input [FINAL_DATA_WIDTH-1:0] CsrOutW,
    
    input logic [FINAL_DATA_WIDTH-1:0] ResultW,
    input logic [FINAL_ADDR_WIDTH-1:0] PCF
);


    writeback_interface wb_intf 
    (
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
    
    initial
    begin
        uvm_config_db #(virtual writeback_interface)::set(null,"","INTF",wb_intf.TEST);
    end
endinterface