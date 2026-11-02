import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface execute_wr 
(
    input clk,
    input logic rst,
    input logic ValidE,
    input logic signed [FINAL_DATA_WIDTH-1:0] RD1E,
    input logic signed [FINAL_DATA_WIDTH-1:0] RD2E,
    input logic signed [FINAL_DATA_WIDTH-1:0] SignImmE,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4E,
    input logic [FINAL_DATA_WIDTH-1:0] PCBranchE,
    input alu_operation_t ALUControlE,
    input logic [2:0] funct3E,
    input logic BranchE,
    input logic JumpE,
    input logic JalrE,
    input logic AuipcE,
    input logic WordOpE,
    input logic [2:0] ForwardAE,
    input logic [2:0] ForwardBE,
    input gpr_t Rs1E,
    input gpr_t RdE,
    input logic RegWriteE,
    input logic CsrAccessE,
    input csr_t CsrOperationE,
    input csr_index_t CsrIndexE,
    input selector_t SelectorE,
    input logic ALUSrcE,
    input logic MemWriteE,
    input logic MemReadE,
    input logic MRetE,
    input logic EcallE,
    input logic EbreakE,
    input logic IllegaleInstructionE,
    input fpr_t RdFE,
    input logic [FINAL_FLP_WIDTH-1:0] RD1FE,
    input logic [FINAL_FLP_WIDTH-1:0] RD2FE,
    input fpu_operation_t FPUControlE,
    input round_mode_t RoundModeE,
    input logic FPURegWriteE,
    input logic FPUValidE,
    input move_operation_t MoveOperationE,
    input logic [1:0] ForwardFloatingAE,
    input logic [1:0] ForwardFloatingBE,
    input fpr_t Rs1FE,
    input fpr_t Rs2FE,
    input logic signed [FINAL_DATA_WIDTH-1:0] ResultW,
    input logic [FINAL_FLP_WIDTH-1:0] FPUOutW,
    input logic TimerInterrupt,
    input logic ExternalInterrupt,
    input logic SoftwareInterrupt,
    input logic StallE,
    input logic StallM,
    input logic FlushM,
    input logic ValidM,
    input logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM,
    input logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM,
    input gpr_t RdM,
    input logic PCSrcE,
    input logic [FINAL_DATA_WIDTH-1:0] PCTargetE,
    input logic RegWriteM,
    input logic [FINAL_DATA_WIDTH-1:0] PCPlus4M,
    input selector_t SelectorM,
    input logic [2:0] funct3M,
    input logic [FINAL_DATA_WIDTH-1:0] CsrOutM,
    input logic MemWriteM,
    input logic MemReadM,
    input logic TrapIsSet,
    input logic [FINAL_DATA_WIDTH-1:0] CsrOutPC,
    input fpr_t RdFM,
    input logic OverflowM,
    input logic UnderflowM,
    input logic NaNM,
    input logic InfM,
    input logic ZeroM,
    input logic InvalidDivM,
    input logic [FINAL_FLP_WIDTH-1:0] FPUOutM,
    input logic FPURegWriteM,
    input move_operation_t MoveOperationM,
    input logic FPUBusyE,
    input logic FPUDoneE
);

    execute_interface execute_intf 
    (
        .clk(clk)
    );

    // MemStallBit is a stand-alone stimulus; in the core the real StallE /
    // StallM / FlushM are observed instead.
    always_comb
    begin
        execute_intf.rst = rst;
        execute_intf.ValidE = ValidE;
        execute_intf.RD1E = RD1E;
        execute_intf.RD2E = RD2E;
        execute_intf.SignImmE = SignImmE;
        execute_intf.PCPlus4E = PCPlus4E;
        execute_intf.PCBranchE = PCBranchE;
        execute_intf.ALUControlE = ALUControlE;
        execute_intf.funct3E = funct3E;
        execute_intf.BranchE = BranchE;
        execute_intf.JumpE = JumpE;
        execute_intf.JalrE = JalrE;
        execute_intf.AuipcE = AuipcE;
        execute_intf.WordOpE = WordOpE;
        execute_intf.ForwardAE = ForwardAE;
        execute_intf.ForwardBE = ForwardBE;
        execute_intf.Rs1E = Rs1E;
        execute_intf.RdE = RdE;
        execute_intf.RegWriteE = RegWriteE;
        execute_intf.CsrAccessE = CsrAccessE;
        execute_intf.CsrOperationE = CsrOperationE;
        execute_intf.CsrIndexE = CsrIndexE;
        execute_intf.SelectorE = SelectorE;
        execute_intf.ALUSrcE = ALUSrcE;
        execute_intf.MemWriteE = MemWriteE;
        execute_intf.MemReadE = MemReadE;
        execute_intf.MRetE = MRetE;
        execute_intf.EcallE = EcallE;
        execute_intf.EbreakE = EbreakE;
        execute_intf.IllegaleInstructionE = IllegaleInstructionE;
        execute_intf.RdFE = RdFE;
        execute_intf.RD1FE = RD1FE;
        execute_intf.RD2FE = RD2FE;
        execute_intf.FPUControlE = FPUControlE;
        execute_intf.RoundModeE = RoundModeE;
        execute_intf.FPURegWriteE = FPURegWriteE;
        execute_intf.FPUValidE = FPUValidE;
        execute_intf.MoveOperationE = MoveOperationE;
        execute_intf.ForwardFloatingAE = ForwardFloatingAE;
        execute_intf.ForwardFloatingBE = ForwardFloatingBE;
        execute_intf.Rs1FE = Rs1FE;
        execute_intf.Rs2FE = Rs2FE;
        execute_intf.ResultW = ResultW;
        execute_intf.FPUOutW = FPUOutW;
        execute_intf.TimerInterrupt = TimerInterrupt;
        execute_intf.ExternalInterrupt = ExternalInterrupt;
        execute_intf.SoftwareInterrupt = SoftwareInterrupt;
        execute_intf.StallE = StallE;
        execute_intf.StallM = StallM;
        execute_intf.FlushM = FlushM;
        execute_intf.ValidM = ValidM;
        execute_intf.ALUOutM = ALUOutM;
        execute_intf.WriteDataM = WriteDataM;
        execute_intf.RdM = RdM;
        execute_intf.PCSrcE = PCSrcE;
        execute_intf.PCTargetE = PCTargetE;
        execute_intf.RegWriteM = RegWriteM;
        execute_intf.PCPlus4M = PCPlus4M;
        execute_intf.SelectorM = SelectorM;
        execute_intf.funct3M = funct3M;
        execute_intf.CsrOutM = CsrOutM;
        execute_intf.MemWriteM = MemWriteM;
        execute_intf.MemReadM = MemReadM;
        execute_intf.TrapIsSet = TrapIsSet;
        execute_intf.CsrOutPC = CsrOutPC;
        execute_intf.RdFM = RdFM;
        execute_intf.OverflowM = OverflowM;
        execute_intf.UnderflowM = UnderflowM;
        execute_intf.NaNM = NaNM;
        execute_intf.InfM = InfM;
        execute_intf.ZeroM = ZeroM;
        execute_intf.InvalidDivM = InvalidDivM;
        execute_intf.FPUOutM = FPUOutM;
        execute_intf.FPURegWriteM = FPURegWriteM;
        execute_intf.MoveOperationM = MoveOperationM;
        execute_intf.FPUBusyE = FPUBusyE;
        execute_intf.FPUDoneE = FPUDoneE;
        execute_intf.MemStallBit = 1'b0;
    end

    initial
    begin
        uvm_config_db #(virtual execute_interface)::set(null,"","INTF",execute_intf.RISC);
    end
endinterface
