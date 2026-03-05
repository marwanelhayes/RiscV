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
    input [DATA_WIDTH-1:0] RD1FE,
    input [DATA_WIDTH-1:0] RD2FE,
    input fpu_operation_t FPUControlE,
    input round_mode_t RoundModeE,
    input FPURegWriteE,
    input move_operation_t MoveOperationE,
    input logic [DATA_WIDTH-1:0] FPUOutW,
    input logic [1:0] ForwardFloatingAE,
    input logic [1:0] ForwardFloatingBE,
    input fpr_t Rs1FE,
    input fpr_t Rs2FE,

    input logic signed [DATA_WIDTH-1:0] ALUOutM,
    input logic signed [DATA_WIDTH-1:0] WriteDataM,
    input gpr_t RdM,
    input logic PCSrcE,
    input logic RegWriteM,
    input logic [ADDR_WIDTH-1:0] PCPlus4M,
    input selector_t SelectorM,
    input logic [2:0] funct3M,
    input logic [DATA_WIDTH-1:0] CsrOutM,
    input logic MemWriteM,
    input logic TrapIsSet,
    input logic [ADDR_WIDTH-1:0] CsrOutPC,
    input fpr_t RdFM,
    input logic OverflowM,
    input logic UnderflowM,
    input logic NaNM,
    input logic InfM,
    input logic ZeroM,
    input logic InvalidDivM,
    input logic [DATA_WIDTH-1:0] FPUOutM,
    input logic FPURegWriteM,
    input move_operation_t MoveOperationM
);

    execute_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) execute_intf (
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
        /*
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
        assign execute_intf.MRetE = MRetE;
        assign execute_intf.EcallE = EcallE;
        assign execute_intf.EbreakE = EbreakE;
        assign execute_intf.IllegaleInstructionE = IllegaleInstructionE;
        assign execute_intf.TimerInterrupt = TimerInterrupt;
        assign execute_intf.ExternalInterrupt = ExternalInterrupt;
        assign execute_intf.SoftwareInterrupt = SoftwareInterrupt;
        assign execute_intf.RdFE = RdFE;
        assign execute_intf.RD1FE = RD1FE;
        assign execute_intf.RD2FE = RD2FE;
        assign execute_intf.FPUControlE = FPUControlE;
        assign execute_intf.RoundModeE = RoundModeE;
        assign execute_intf.FPURegWriteE = FPURegWriteE;
        assign execute_intf.MoveOperationE = MoveOperationE;
        assign execute_intf.FPUOutW = FPUOutW;
        assign execute_intf.ForwardFloatingAE = ForwardFloatingAE;
        assign execute_intf.ForwardFloatingBE = ForwardFloatingBE;
        assign execute_intf.Rs1FE = Rs1FE;
        assign execute_intf.Rs2FE = Rs2FE;

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
        assign execute_intf.TrapIsSet = TrapIsSet;
        assign execute_intf.CsrOutPC = CsrOutPC;
        assign execute_intf.RdFM = RdFM;
        assign execute_intf.OverflowM = OverflowM;
        assign execute_intf.UnderflowM = UnderflowM;
        assign execute_intf.NaNM = NaNM;
        assign execute_intf.InfM = InfM;
        assign execute_intf.ZeroM = ZeroM;
        assign execute_intf.InvalidDivM = InvalidDivM;
        assign execute_intf.FPUOutM = FPUOutM;
        assign execute_intf.FPURegWriteM = FPURegWriteM;
        assign execute_intf.MoveOperationM = MoveOperationM;
*/
    initial
    begin
        uvm_config_db #( virtual execute_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)))::set(null,"","INTF",execute_intf.TEST);
    end
endinterface
