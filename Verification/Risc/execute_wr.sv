import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;
interface execute_wr 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] RD1E,
    input signed [DATA_WIDTH-1:0] RD2E,
    input signed [DATA_WIDTH-1:0] SignImmE,
    input signed [DATA_WIDTH-1:0] ResultW,
    input [ADDR_WIDTH-1:0] PCPlus4E,
    input alu_operation_t ALUControlE,
    input logic [2:0] funct3E,
    input BranchE,
    input JumpE,
    input [1:0] ForwardAE,
    input [1:0] ForwardBE,
    input gpr_t Rs1E,
    input gpr_t RdE,
    input RegWriteE,
    input CsrAccessE,
    input csr_t CsrOperationE,
    input csr_index_t CsrIndexE,
    input selector_t SelectorE,
    input ALUSrcE,
    input MemWriteE,
    
    input logic signed [DATA_WIDTH-1:0] ALUOutM,
    input logic signed [DATA_WIDTH-1:0] WriteDataM,
    input gpr_t RdM,
    input logic PCSrcE,
    input logic RegWriteM,
    input logic [ADDR_WIDTH-1:0] PCPlus4M,
    input selector_t SelectorM,
    input logic [2:0] funct3M,
    input logic [DATA_WIDTH-1:0] CsrOutM,
    input logic MemWriteM
);

    execute_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) execute_intf (
        .clk(clk)
    );

        assign execute_intf.rst = rst;
        assign execute_intf.RD1E = RD1E;
        assign execute_intf.RD2E = RD2E;
        assign execute_intf.SignImmE = SignImmE;
        assign execute_intf.ResultW = ResultW;
        assign execute_intf.PCPlus4E = PCPlus4E;
        assign execute_intf.ALUControlE = ALUControlE;
        assign execute_intf.funct3E = funct3E;
        assign execute_intf.BranchE = BranchE;
        assign execute_intf.JumpE = JumpE;
        assign execute_intf.ForwardAE = ForwardAE;
        assign execute_intf.ForwardBE = ForwardBE;
        assign execute_intf.Rs1E = Rs1E;
        assign execute_intf.RdE = RdE;
        assign execute_intf.RegWriteE = RegWriteE;
        assign execute_intf.CsrAccessE = CsrAccessE;
        assign execute_intf.CsrOperationE = CsrOperationE;
        assign execute_intf.CsrIndexE = CsrIndexE;
        assign execute_intf.SelectorE = SelectorE;
        assign execute_intf.ALUSrcE = ALUSrcE;
        assign execute_intf.MemWriteE = MemWriteE;

        assign execute_intf.ALUOutM = ALUOutM;
        assign execute_intf.WriteDataM = WriteDataM;
        assign execute_intf.RdM = RdM;
        assign execute_intf.PCSrcE = PCSrcE;
        assign execute_intf.RegWriteM = RegWriteM;
        assign execute_intf.PCPlus4M = PCPlus4M;
        assign execute_intf.SelectorM = SelectorM;
        assign execute_intf.funct3M = funct3M;
        assign execute_intf.CsrOutM = CsrOutM;
        assign execute_intf.MemWriteM = MemWriteM;

    initial
    begin
        uvm_config_db #( virtual execute_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)))::set(null,"","INTF",execute_intf.TEST);
    end
endinterface
