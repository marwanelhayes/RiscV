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
    input fpr_t RdFM,
    input logic OverflowM,
    input logic UnderflowM,
    input logic NaNM,
    input logic InfM,
    input logic ZeroM,
    input logic InvalidDivM,
    input logic [DATA_WIDTH-1:0] FPUOutM,
    input move_operation_t MoveOperationM,
    input FPURegWriteM,
    
    input logic signed [DATA_WIDTH-1:0] ReadDataW,
    input gpr_t RdW,
    input logic RegWriteW,
    input selector_t SelectorW,
    input logic [ADDR_WIDTH-1:0] PCPlus4W,
    input logic [DATA_WIDTH-1:0] CsrOutW,
    input logic signed [DATA_WIDTH-1:0] ALUOutW,
    input fpr_t RdFW,
    input logic OverflowW,
    input logic UnderflowW,
    input logic NaNW,
    input logic InfW,    
    input logic ZeroW,
    input logic InvalidDivW,
    input logic [DATA_WIDTH-1:0] FPUOutW,
    input move_operation_t MoveOperationW,
    input logic FPURegWriteW
);
    mem_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) mem_intf (
        .clk(clk)
    );
    always_comb
    begin
        mem_intf.rst = rst;
        mem_intf.ALUOutM = ALUOutM;
        mem_intf.WriteDataM = WriteDataM;
        mem_intf.PCPlus4M = PCPlus4M;
        mem_intf.RdM = RdM;
        mem_intf.funct3M = funct3M;
        mem_intf.RegWriteM = RegWriteM;
        mem_intf.CsrOutM = CsrOutM;
        mem_intf.SelectorM = SelectorM;
        mem_intf.MemWriteM = MemWriteM;
        mem_intf.RdFM = RdFM;
        mem_intf.OverflowM = OverflowM;
        mem_intf.UnderflowM = UnderflowM;
        mem_intf.NaNM = NaNM;
        mem_intf.InfM = InfM;
        mem_intf.ZeroM = ZeroM;
        mem_intf.InvalidDivM = InvalidDivM;
        mem_intf.FPUOutM = FPUOutM;
        mem_intf.MoveOperationM = MoveOperationM;
        mem_intf.FPURegWriteM = FPURegWriteM;

        mem_intf.ReadDataW = ReadDataW;
        mem_intf.RdW = RdW;
        mem_intf.RegWriteW = RegWriteW;
        mem_intf.SelectorW = SelectorW;
        mem_intf.PCPlus4W = PCPlus4W;
        mem_intf.CsrOutW = CsrOutW;
        mem_intf.ALUOutW = ALUOutW;
        mem_intf.RdFW = RdFW;
        mem_intf.OverflowW = OverflowW;
        mem_intf.UnderflowW = UnderflowW;
        mem_intf.NaNW = NaNW;
        mem_intf.InfW = InfW;
        mem_intf.ZeroW = ZeroW;
        mem_intf.InvalidDivW = InvalidDivW;
        mem_intf.FPUOutW = FPUOutW;
        mem_intf.MoveOperationW = MoveOperationW;
        mem_intf.FPURegWriteW = FPURegWriteW;
    end
    /*
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
    assign mem_intf.RdFM = RdFM;
    assign mem_intf.OverflowM = OverflowM;
    assign mem_intf.UnderflowM = UnderflowM;
    assign mem_intf.NaNM = NaNM;
    assign mem_intf.InfM = InfM;
    assign mem_intf.ZeroM = ZeroM;
    assign mem_intf.InvalidDivM = InvalidDivM;
    assign mem_intf.FPUOutM = FPUOutM;
    assign mem_intf.MoveOperationM = MoveOperationM;
    assign mem_intf.FPURegWriteM = FPURegWriteM;

    assign mem_intf.ReadDataW = ReadDataW;
    assign mem_intf.RdW = RdW;
    assign mem_intf.RegWriteW = RegWriteW;
    assign mem_intf.SelectorW = SelectorW;
    assign mem_intf.PCPlus4W = PCPlus4W;
    assign mem_intf.CsrOutW = CsrOutW;
    assign mem_intf.ALUOutW = ALUOutW;
    assign mem_intf.RdFW = RdFW;
    assign mem_intf.OverflowW = OverflowW;
    assign mem_intf.UnderflowW = UnderflowW;
    assign mem_intf.NaNW = NaNW;
    assign mem_intf.InfW = InfW;
    assign mem_intf.ZeroW = ZeroW;
    assign mem_intf.InvalidDivW = InvalidDivW;
    assign mem_intf.FPUOutW = FPUOutW;
    assign mem_intf.MoveOperationW = MoveOperationW;
    assign mem_intf.FPURegWriteW = FPURegWriteW;
*/
    initial
    begin
        uvm_config_db #(virtual mem_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH( ADDR_WIDTH)))::set(null,"","INTF",mem_intf.TEST);
    end


endinterface