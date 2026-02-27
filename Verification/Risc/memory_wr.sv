import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface memory_wr 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] ALUOutM,
    input signed [DATA_WIDTH-1:0] WriteDataM,
    input [ADDR_WIDTH-1:0] PCPlus4M,
    input gpr_t RdM,
    input logic [2:0] funct3M,
    input RegWriteM,
    input logic [DATA_WIDTH-1:0] CsrOutM,
    input selector_t SelectorM,
    input MemWriteM,
    
    input logic signed [DATA_WIDTH-1:0] ReadDataW,
    input gpr_t RdW,
    input logic RegWriteW,
    input selector_t SelectorW,
    input logic [ADDR_WIDTH-1:0] PCPlus4W,
    input logic [DATA_WIDTH-1:0] CsrOutW,
    input logic signed [DATA_WIDTH-1:0] ALUOutW
);
    mem_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) mem_intf (
        .clk(clk)
    );

    assign mem_intf.rst = rst;
    assign mem_intf.ALUOutM = ALUOutM;
    assign mem_intf.WriteDataM = WriteDataM;
    assign mem_intf.PCPlus4M = PCPlus4M;
    assign mem_intf.RdM = RdM;
    assign mem_intf.funct3M = funct3M;
    assign mem_intf.RegWriteM = RegWriteM;
    assign mem_intf.CsrOutM = CsrOutM;
    assign mem_intf.SelectorM = SelectorM;
    assign mem_intf.MemWriteM = MemWriteM;

    assign mem_intf.ReadDataW = ReadDataW;
    assign mem_intf.RdW = RdW;
    assign mem_intf.RegWriteW = RegWriteW;
    assign mem_intf.SelectorW = SelectorW;
    assign mem_intf.PCPlus4W = PCPlus4W;
    assign mem_intf.CsrOutW = CsrOutW;
    assign mem_intf.ALUOutW = ALUOutW;

    initial
    begin
        uvm_config_db #(virtual mem_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH( ADDR_WIDTH)))::set(null,"","INTF",mem_intf.TEST);
    end


endinterface