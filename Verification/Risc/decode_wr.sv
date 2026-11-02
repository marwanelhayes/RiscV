import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface decode_wr 
(
    input clk,
    input rst,
    input [FINAL_DATA_WIDTH-1:0] PCPlus4D,
    input [INSTR_WIDTH-1:0] InstructionD,
    input ValidD,
    input gpr_t RdW,
    input RegWriteW,
    input signed [FINAL_DATA_WIDTH-1:0] ResultW,
    input fpr_t RdFW,
    input [FINAL_FLP_WIDTH-1:0] FPUOutW,
    input FPURegWriteW,
    input FlushE,
    input StallE,
    input gpr_t Rs1E,
    input gpr_t Rs2E,
    input gpr_t Rs1D,
    input gpr_t Rs2D,
    input gpr_t RdE,
    input logic signed [FINAL_DATA_WIDTH-1:0] RD1E,
    input logic signed [FINAL_DATA_WIDTH-1:0] RD2E,
    input logic ValidE,
    input logic JumpE,
    input logic JalrE,
    input alu_operation_t ALUControlE,
    input logic signed [FINAL_DATA_WIDTH-1:0] SignImmE,
    input logic [FINAL_DATA_WIDTH-1:0] PCBranchE,
    input logic RegWriteE,
    input selector_t SelectorE,
    input logic MemWriteE,
    input logic MemReadE,
    input logic BranchE,
    input logic ALUSrcE,
    input logic AuipcE,
    input logic WordOpE,
    input csr_t CsrOperationE,
    input csr_index_t CsrIndexE,
    input logic CsrAccessE,
    input logic EcallE,
    input logic EbreakE,
    input logic MRetE,
    input logic IllegaleInstructionE,
    input logic [2:0] funct3E,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4E,
    input fpr_t RdFE,
    input logic [FINAL_FLP_WIDTH-1:0] RD1FE,
    input logic [FINAL_FLP_WIDTH-1:0] RD2FE,
    input fpu_operation_t FPUControlE,
    input round_mode_t RoundModeE,
    input logic FPURegWriteE,
    input move_operation_t MoveOperationE,
    input fpr_t Rs1FE,
    input fpr_t Rs2FE,
    input logic FPUValidE
);

    decode_interface decode_intf
    (
        .clk(clk)
    );

    always_comb
    begin
        decode_intf.rst = rst;
        decode_intf.PCPlus4D = PCPlus4D;
        decode_intf.InstructionD = InstructionD;
        decode_intf.ValidD = ValidD;
        decode_intf.RdW = RdW;
        decode_intf.RegWriteW = RegWriteW;
        decode_intf.ResultW = ResultW;
        decode_intf.RdFW = RdFW;
        decode_intf.FPUOutW = FPUOutW;
        decode_intf.FPURegWriteW = FPURegWriteW;
        decode_intf.FlushE = FlushE;
        decode_intf.StallE = StallE;
        decode_intf.Rs1E = Rs1E;
        decode_intf.Rs2E = Rs2E;
        decode_intf.Rs1D = Rs1D;
        decode_intf.Rs2D = Rs2D;
        decode_intf.RdE = RdE;
        decode_intf.RD1E = RD1E;
        decode_intf.RD2E = RD2E;
        decode_intf.ValidE = ValidE;
        decode_intf.JumpE = JumpE;
        decode_intf.JalrE = JalrE;
        decode_intf.ALUControlE = ALUControlE;
        decode_intf.SignImmE = SignImmE;
        decode_intf.PCBranchE = PCBranchE;
        decode_intf.RegWriteE = RegWriteE;
        decode_intf.SelectorE = SelectorE;
        decode_intf.MemWriteE = MemWriteE;
        decode_intf.MemReadE = MemReadE;
        decode_intf.BranchE = BranchE;
        decode_intf.ALUSrcE = ALUSrcE;
        decode_intf.AuipcE = AuipcE;
        decode_intf.WordOpE = WordOpE;
        decode_intf.CsrOperationE = CsrOperationE;
        decode_intf.CsrIndexE = CsrIndexE;
        decode_intf.CsrAccessE = CsrAccessE;
        decode_intf.EcallE = EcallE;
        decode_intf.EbreakE = EbreakE;
        decode_intf.MRetE = MRetE;
        decode_intf.IllegaleInstructionE = IllegaleInstructionE;
        decode_intf.funct3E = funct3E;
        decode_intf.PCPlus4E = PCPlus4E;
        decode_intf.RdFE = RdFE;
        decode_intf.RD1FE = RD1FE;
        decode_intf.RD2FE = RD2FE;
        decode_intf.FPUControlE = FPUControlE;
        decode_intf.RoundModeE = RoundModeE;
        decode_intf.FPURegWriteE = FPURegWriteE;
        decode_intf.MoveOperationE = MoveOperationE;
        decode_intf.Rs1FE = Rs1FE;
        decode_intf.Rs2FE = Rs2FE;
        decode_intf.FPUValidE = FPUValidE;
    end

    initial
    begin
        uvm_config_db #(virtual decode_interface)::set(null,"","INTF",decode_intf);
    end

endinterface
