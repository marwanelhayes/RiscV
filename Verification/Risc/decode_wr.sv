import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface decode_wr 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] PCPlus4D,
    input [DATA_WIDTH-1:0] InstructionD,
    input gpr_t RdW,
    input FlushE,
    input RegWriteW,
    input signed [DATA_WIDTH-1:0] ResultW,
    
    input gpr_t Rs1E,
    input gpr_t Rs2E,
    input gpr_t Rs1D,
    input gpr_t Rs2D,
    input gpr_t RdE,
    input logic JumpE,
    input alu_operation_t ALUControlE,
    input csr_t CsrOperationE,
    input logic signed [DATA_WIDTH-1:0] RD1E,
    input logic signed [DATA_WIDTH-1:0] RD2E,
    input logic signed [DATA_WIDTH-1:0] SignImmE,
    input logic [ADDR_WIDTH-1:0] PCBranchE,
    input csr_index_t CsrIndexE,
    input logic [2:0] funct3E,
    input logic [ADDR_WIDTH-1:0] PCPlus4E,
    input logic RegWriteE , 
    input selector_t SelectorE,
    input logic MemWriteE,
    input logic BranchE,
    input logic CsrAccessE,
    input logic ALUSrcE
);

    decode_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) 
    decode_intf 
    (
        .clk(clk)
    );


    assign decode_intf.rst = rst ; 
    assign decode_intf.PCPlus4D = PCPlus4D ; 
    assign decode_intf.InstructionD = InstructionD ; 
    assign decode_intf.RdW = RdW ; 
    assign decode_intf.FlushE = FlushE ; 
    assign decode_intf.RegWriteW = RegWriteW ; 
    assign decode_intf.ResultW = ResultW ; 
    
    assign decode_intf.Rs1E = Rs1E ; 
    assign decode_intf.Rs2E = Rs2E ; 
    assign decode_intf.Rs1D = Rs1D ; 
    assign decode_intf.Rs2D = Rs2D ; 
    assign decode_intf.RdE = RdE ; 
    assign decode_intf.JumpE = JumpE ; 
    assign decode_intf.ALUControlE = ALUControlE ; 
    assign decode_intf.CsrOperationE = CsrOperationE ; 
    assign decode_intf.RD1E = RD1E ; 
    assign decode_intf.RD2E = RD2E ; 
    assign decode_intf.SignImmE = SignImmE ; 
    assign decode_intf.PCBranchE = PCBranchE ; 
    assign decode_intf.CsrIndexE = CsrIndexE ; 
    assign decode_intf.funct3E = funct3E ; 
    assign decode_intf.PCPlus4E = PCPlus4E ; 
    assign decode_intf.RegWriteE = RegWriteE ; 
    assign decode_intf.SelectorE = SelectorE ; 
    assign decode_intf.MemWriteE = MemWriteE ; 
    assign decode_intf.BranchE = BranchE ; 
    assign decode_intf.CsrAccessE = CsrAccessE ; 
    assign decode_intf.ALUSrcE = ALUSrcE ; 

    initial 
    begin
        uvm_config_db #(virtual decode_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)))::set(null,"","INTF",decode_intf.TEST);
    end

endinterface