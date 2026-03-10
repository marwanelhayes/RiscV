import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;
interface execute_wr 
(
    input clk,
    input rst,
    input signed [FINAL_DATA_WIDTH-1:0] RD1E,
    input signed [FINAL_DATA_WIDTH-1:0] RD2E,
    input signed [FINAL_DATA_WIDTH-1:0] SignImmE,
    input signed [FINAL_DATA_WIDTH-1:0] ResultW,
    input [FINAL_ADDR_WIDTH-1:0] PCPlus4E,
    input alu_operation_t ALUControlE,
    input logic [2:0] funct3E,
    input BranchE,
    input JumpE,
    input [2:0] ForwardAE,
    input [2:0] ForwardBE,
    input gpr_t Rs1E,
    input gpr_t RdE,
    input RegWriteE,
    input CsrAccessE,
    input csr_t CsrOperationE,
    input csr_index_t CsrIndexE,
    input selector_t SelectorE,
    input ALUSrcE,
    input MemWriteE,
    input MRetE,
    input EcallE,
    input EbreakE,
    input IllegaleInstructionE,
    input TimerInterrupt,
    input ExternalInterrupt,
    input SoftwareInterrupt,
    input fpr_t RdFE,
    input [FINAL_DATA_WIDTH-1:0] RD1FE,
    input [FINAL_DATA_WIDTH-1:0] RD2FE,
    input fpu_operation_t FPUControlE,
    input round_mode_t RoundModeE,
    input FPURegWriteE,
    input move_operation_t MoveOperationE,
    input logic [FINAL_DATA_WIDTH-1:0] FPUOutW,
    input logic [1:0] ForwardFloatingAE,
    input logic [1:0] ForwardFloatingBE,
    input fpr_t Rs1FE,
    input fpr_t Rs2FE,

    input logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM,
    input logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM,
    input gpr_t RdM,
    input logic PCSrcE,
    input logic RegWriteM,
    input logic [FINAL_ADDR_WIDTH-1:0] PCPlus4M,
    input selector_t SelectorM,
    input logic [2:0] funct3M,
    input logic [FINAL_DATA_WIDTH-1:0] CsrOutM,
    input logic MemWriteM,
    input logic TrapIsSet,
    input logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC,
    input fpr_t RdFM,
    input logic OverflowM,
    input logic UnderflowM,
    input logic NaNM,
    input logic InfM,
    input logic ZeroM,
    input logic InvalidDivM,
    input logic [FINAL_DATA_WIDTH-1:0] FPUOutM,
    input logic FPURegWriteM,
    input move_operation_t MoveOperationM
);

    execute_interface execute_intf 
    (
        .clk(clk)
    );

        always_comb
        begin
            execute_intf.rst = rst;
            execute_intf.RD1E = RD1E;
            execute_intf.RD2E = RD2E;
            execute_intf.SignImmE = SignImmE;
            execute_intf.ResultW = ResultW;
            execute_intf.PCPlus4E = PCPlus4E;
            execute_intf.ALUControlE = ALUControlE;
            execute_intf.funct3E = funct3E;
            execute_intf.BranchE = BranchE;
            execute_intf.JumpE = JumpE;
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
            execute_intf.MRetE = MRetE;
            execute_intf.EcallE = EcallE;
            execute_intf.EbreakE = EbreakE;
            execute_intf.IllegaleInstructionE = IllegaleInstructionE;
            execute_intf.TimerInterrupt = TimerInterrupt;
            execute_intf.ExternalInterrupt = ExternalInterrupt;
            execute_intf.SoftwareInterrupt = SoftwareInterrupt;
            execute_intf.RdFE = RdFE;
            execute_intf.RD1FE = RD1FE;
            execute_intf.RD2FE = RD2FE;
            execute_intf.FPUControlE = FPUControlE;
            execute_intf.RoundModeE = RoundModeE;
            execute_intf.FPURegWriteE = FPURegWriteE;
            execute_intf.MoveOperationE = MoveOperationE;
            execute_intf.FPUOutW = FPUOutW;
            execute_intf.ForwardFloatingAE = ForwardFloatingAE;
            execute_intf.ForwardFloatingBE = ForwardFloatingBE;
            execute_intf.Rs1FE = Rs1FE;
            execute_intf.Rs2FE = Rs2FE;

            execute_intf.ALUOutM = ALUOutM;
            execute_intf.WriteDataM = WriteDataM;
            execute_intf.RdM = RdM;
            execute_intf.PCSrcE = PCSrcE;
            execute_intf.RegWriteM = RegWriteM;
            execute_intf.PCPlus4M = PCPlus4M;
            execute_intf.SelectorM = SelectorM;
            execute_intf.funct3M = funct3M;
            execute_intf.CsrOutM = CsrOutM;
            execute_intf.MemWriteM = MemWriteM;
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
        end
       
    initial
    begin
        uvm_config_db #(virtual execute_interface)::set(null,"","INTF",execute_intf.TEST);
    end
endinterface
