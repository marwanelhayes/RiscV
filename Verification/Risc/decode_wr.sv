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
    input fpr_t RdFW,
    input [DATA_WIDTH-1:0] FPUOutW,
    input move_operation_t MoveOperationW,
    input FPURegWriteW,
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
    input logic ALUSrcE,
    input logic EcallE,
    input logic EbreakE,
    input logic MRetE,
    input logic IllegaleInstructionE,
    input fpr_t RdFE,
    input logic [DATA_WIDTH-1:0] RD1FE,
    input logic [DATA_WIDTH-1:0] RD2FE,
    input fpu_operation_t FPUControlE,
    input round_mode_t RoundModeE,
    input logic FPURegWriteE,
    input move_operation_t MoveOperationE,
    input fpr_t Rs1FE,
    input fpr_t Rs2FE
);

    decode_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) 
    decode_intf 
    (
        .clk(clk)
    );

    always_comb 
    begin
    decode_intf.rst = rst ; 
    decode_intf.PCPlus4D = PCPlus4D ; 
    decode_intf.InstructionD = InstructionD ; 
    decode_intf.RdW = RdW ; 
    decode_intf.FlushE = FlushE ; 
    decode_intf.RegWriteW = RegWriteW ; 
    decode_intf.ResultW = ResultW ; 

    decode_intf.Rs1E = Rs1E ; 
    decode_intf.Rs2E = Rs2E ; 
    decode_intf.Rs1D = Rs1D ; 
    decode_intf.Rs2D = Rs2D ; 
    decode_intf.RdE = RdE ; 
    decode_intf.JumpE = JumpE ; 
    decode_intf.ALUControlE = ALUControlE ; 
    decode_intf.CsrOperationE = CsrOperationE ; 
    decode_intf.RD1E = RD1E ; 
    decode_intf.RD2E = RD2E ; 
    decode_intf.SignImmE = SignImmE ; 
    decode_intf.PCBranchE = PCBranchE ; 
    decode_intf.CsrIndexE = CsrIndexE ; 
    decode_intf.funct3E = funct3E ; 
    decode_intf.PCPlus4E = PCPlus4E ; 
    decode_intf.RegWriteE = RegWriteE ; 
    decode_intf.SelectorE = SelectorE ; 
    decode_intf.MemWriteE = MemWriteE ; 
    decode_intf.BranchE = BranchE ; 
    decode_intf.CsrAccessE = CsrAccessE ; 
    decode_intf.ALUSrcE = ALUSrcE ; 
    decode_intf.EcallE = EcallE ; 
    decode_intf.EbreakE = EbreakE ; 
    decode_intf.MRetE = MRetE ; 
    decode_intf.IllegaleInstructionE = IllegaleInstructionE ; 
    decode_intf.RdFW = RdFW ; 
    decode_intf.FPUOutW = FPUOutW ; 
    decode_intf.MoveOperationW = MoveOperationW ; 
    decode_intf.FPURegWriteW = FPURegWriteW ; 
    decode_intf.RdFE = RdFE ; 
    decode_intf.RD1FE = RD1FE ; 
    decode_intf.RD2FE = RD2FE ; 
    decode_intf.FPUControlE = FPUControlE ; 
    decode_intf.RoundModeE = RoundModeE ; 
    decode_intf.FPURegWriteE = FPURegWriteE ; 
    decode_intf.MoveOperationE = MoveOperationE ; 
    decode_intf.Rs1FE = Rs1FE ; 
    decode_intf.Rs2FE = Rs2FE ; 
    end
    
    /*
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
    assign decode_intf.EcallE = EcallE ; 
    assign decode_intf.EbreakE = EbreakE ; 
    assign decode_intf.MRetE = MRetE ; 
    assign decode_intf.IllegaleInstructionE = IllegaleInstructionE ; 
    assign decode_intf.RdFW = RdFW ; 
    assign decode_intf.FPUOutW = FPUOutW ; 
    assign decode_intf.MoveOperationW = MoveOperationW ; 
    assign decode_intf.FPURegWriteW = FPURegWriteW ; 
    assign decode_intf.RdFE = RdFE ; 
    assign decode_intf.RD1FE = RD1FE ; 
    assign decode_intf.RD2FE = RD2FE ; 
    assign decode_intf.FPUControlE = FPUControlE ; 
    assign decode_intf.RoundModeE = RoundModeE ; 
    assign decode_intf.FPURegWriteE = FPURegWriteE ; 
    assign decode_intf.MoveOperationE = MoveOperationE ; 
    assign decode_intf.Rs1FE = Rs1FE ; 
    assign decode_intf.Rs2FE = Rs2FE ; 
*/
    initial 
    begin
        uvm_config_db #(virtual decode_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)))::set(null,"","INTF",decode_intf.TEST);
    end

endinterface