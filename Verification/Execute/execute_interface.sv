// =============================================================================
// execute_interface.sv
// -----------------------------------------------------------------------------
// Execute verification interface. mck=driver, pck=monitor, TEST=verif modport.
// =============================================================================
import shared_pkg::*;
import execute_item_pkg::*;

interface execute_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    // ─── DUT input signals ──────────────────────────────────────────────────
    logic                                  rst;
    logic signed [FINAL_DATA_WIDTH-1:0]    RD1E, RD2E, SignImmE, ResultW;
    logic [FINAL_ADDR_WIDTH-1:0]           PCPlus4E;
    alu_operation_t                        ALUControlE;
    logic [2:0]                            funct3E;
    logic                                  BranchE, JumpE;
    logic [2:0]                            ForwardAE, ForwardBE;
    gpr_t                                  Rs1E, RdE;
    logic                                  RegWriteE, CsrAccessE;
    csr_t                                  CsrOperationE;
    csr_index_t                            CsrIndexE;
    selector_t                             SelectorE;
    logic                                  ALUSrcE, MemWriteE, MRetE;
    logic                                  EcallE, EbreakE, IllegaleInstructionE;
    logic                                  TimerInterrupt, ExternalInterrupt, SoftwareInterrupt;
    fpr_t                                  RdFE;
    logic [FINAL_DATA_WIDTH-1:0]           RD1FE, RD2FE;
    fpu_operation_t                        FPUControlE;
    round_mode_t                           RoundModeE;
    logic                                  FPURegWriteE, FPUValidE;
    move_operation_t                       MoveOperationE;
    logic [FINAL_DATA_WIDTH-1:0]           FPUOutW;
    logic [1:0]                            ForwardFloatingAE, ForwardFloatingBE;
    fpr_t                                  Rs1FE, Rs2FE;

    // ─── DUT output signals ─────────────────────────────────────────────────
    logic signed [FINAL_DATA_WIDTH-1:0]    ALUOutM, WriteDataM;
    gpr_t                                  RdM;
    logic                                  PCSrcE, RegWriteM;
    logic [FINAL_ADDR_WIDTH-1:0]           PCPlus4M;
    selector_t                             SelectorM;
    logic [2:0]                            funct3M;
    logic [FINAL_DATA_WIDTH-1:0]           CsrOutM;
    logic                                  MemWriteM, TrapIsSet;
    logic [FINAL_ADDR_WIDTH-1:0]           CsrOutPC;
    fpr_t                                  RdFM;
    logic                                  OverflowM, UnderflowM, NaNM, InfM, ZeroM, InvalidDivM;
    logic [FINAL_DATA_WIDTH-1:0]           FPUOutM;
    logic                                  FPURegWriteM;
    move_operation_t                       MoveOperationM;
    logic                                  FPUBusyM, FPUDoneM;

    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst, RD1E, RD2E, SignImmE, ResultW, PCPlus4E, ALUControlE, funct3E;
        output BranchE, JumpE, ForwardAE, ForwardBE, Rs1E, RdE, RegWriteE;
        output CsrAccessE, CsrOperationE, CsrIndexE, SelectorE, ALUSrcE, MemWriteE;
        output MRetE, EcallE, EbreakE, IllegaleInstructionE;
        output TimerInterrupt, ExternalInterrupt, SoftwareInterrupt;
        output RdFE, RD1FE, RD2FE, FPUControlE, RoundModeE, FPURegWriteE, FPUValidE;
        output MoveOperationE, FPUOutW, ForwardFloatingAE, ForwardFloatingBE, Rs1FE, Rs2FE;
        input  ALUOutM, WriteDataM, RdM, PCSrcE, RegWriteM, PCPlus4M, SelectorM, funct3M;
        input  CsrOutM, MemWriteM, TrapIsSet, CsrOutPC;
        input  RdFM, OverflowM, UnderflowM, NaNM, InfM, ZeroM, InvalidDivM;
        input  FPUOutM, FPURegWriteM, MoveOperationM, FPUBusyM, FPUDoneM;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;
        input rst, RD1E, RD2E, SignImmE, ResultW, PCPlus4E, ALUControlE, funct3E;
        input BranchE, JumpE, ForwardAE, ForwardBE, Rs1E, RdE, RegWriteE;
        input CsrAccessE, CsrOperationE, CsrIndexE, SelectorE, ALUSrcE, MemWriteE;
        input MRetE, EcallE, EbreakE, IllegaleInstructionE;
        input TimerInterrupt, ExternalInterrupt, SoftwareInterrupt;
        input RdFE, RD1FE, RD2FE, FPUControlE, RoundModeE, FPURegWriteE, FPUValidE;
        input MoveOperationE, FPUOutW, ForwardFloatingAE, ForwardFloatingBE, Rs1FE, Rs2FE;
        input ALUOutM, WriteDataM, RdM, PCSrcE, RegWriteM, PCPlus4M, SelectorM, funct3M;
        input CsrOutM, MemWriteM, TrapIsSet, CsrOutPC;
        input RdFM, OverflowM, UnderflowM, NaNM, InfM, ZeroM, InvalidDivM;
        input FPUOutM, FPURegWriteM, MoveOperationM, FPUBusyM, FPUDoneM;
    endclocking:pck

    task initialize ();
        rst <= 1'b0;
        RD1E <= '0; 
        RD2E <= '0; 
        SignImmE <= '0; 
        ResultW <= '0; 
        PCPlus4E <= '0;
        ALUControlE <= ADD; 
        funct3E <= '0;
        BranchE <= 1'b0; 
        JumpE <= 1'b0;
        ForwardAE <= '0; 
        ForwardBE <= '0;
        Rs1E <= zero; 
        RdE <= zero;
        RegWriteE <= 1'b0; 
        CsrAccessE <= 1'b0;
        CsrOperationE <= csrrw; 
        CsrIndexE <= mstatus;
        SelectorE <= ALUToReg;
        ALUSrcE <= 1'b0; 
        MemWriteE <= 1'b0;
        MRetE <= 1'b0; 
        EcallE <= 1'b0; 
        EbreakE <= 1'b0; 
        IllegaleInstructionE <= 1'b0;
        TimerInterrupt <= 1'b0; 
        ExternalInterrupt <= 1'b0; 
        SoftwareInterrupt <= 1'b0;
        RdFE <= f0; RD1FE <= '0; 
        RD2FE <= '0;
        FPUControlE <= NOOPERATION; 
        RoundModeE <= RNE;
        FPURegWriteE <= 1'b0; 
        FPUValidE <= 1'b0;
        MoveOperationE <= FPUToFPU; 
        FPUOutW <= '0;
        ForwardFloatingAE <= '0; 
        ForwardFloatingBE <= '0;
        Rs1FE <= f0; 
        Rs2FE <= f0;
        repeat(5) @(posedge clk);
        rst <= 1'b1;
    endtask:initialize

    task drv2intf (execute_item drv);
        @(mck);
        mck.rst <= drv.rst;
        if(!pck.PCSrcE)
        begin
            mck.RD1E <= drv.RD1E;
            mck.RD2E <= drv.RD2E;
            mck.SignImmE <= drv.SignImmE;
            mck.ResultW <= drv.ResultW;
            mck.PCPlus4E <= drv.PCPlus4E;
            mck.ALUControlE <= drv.ALUControlE;
            mck.funct3E <= drv.funct3E;
            mck.BranchE <= drv.BranchE;
            mck.JumpE <= drv.JumpE;
            mck.ForwardAE <= drv.ForwardAE;
            mck.ForwardBE <= drv.ForwardBE;
            mck.Rs1E <= drv.Rs1E;
            mck.RdE <= drv.RdE;
            mck.RegWriteE <= drv.RegWriteE;
            mck.CsrAccessE <= drv.CsrAccessE;
            mck.CsrOperationE <= drv.CsrOperationE;
            mck.CsrIndexE <= drv.CsrIndexE;
            mck.SelectorE <= drv.SelectorE;
            mck.ALUSrcE <= drv.ALUSrcE;
            mck.MemWriteE <= drv.MemWriteE;
            mck.MRetE <= drv.MRetE;
            mck.EcallE <= drv.EcallE;
            mck.EbreakE <= drv.EbreakE;
            mck.IllegaleInstructionE <= drv.IllegaleInstructionE;
            mck.TimerInterrupt <= drv.TimerInterrupt;
            mck.SoftwareInterrupt <= drv.SoftwareInterrupt;
            mck.ExternalInterrupt <= drv.ExternalInterrupt;
            mck.RdFE <= drv.RdFE;
            mck.RD1FE <= drv.RD1FE;
            mck.RD2FE <= drv.RD2FE;
            mck.FPUControlE <= drv.FPUControlE;
            mck.RoundModeE <= drv.RoundModeE;
            mck.FPURegWriteE <= drv.FPURegWriteE;
            mck.FPUValidE <= drv.FPUValidE;
            mck.MoveOperationE <= drv.MoveOperationE;
            mck.FPUOutW <= drv.FPUOutW;
            mck.ForwardFloatingAE <= drv.ForwardFloatingAE;
            mck.ForwardFloatingBE <= drv.ForwardFloatingBE;
            mck.Rs1FE <= drv.Rs1FE;
            mck.Rs2FE <= drv.Rs2FE;
        end
        else
        begin
            mck.RD1E <= '0; 
            mck.RD2E <= '0; 
            mck.SignImmE <= '0; 
            mck.ResultW <= '0; 
            mck.PCPlus4E <= '0;
            mck.ALUControlE <= ADD; 
            mck.funct3E <= '0;
            mck.BranchE <= 1'b0; 
            mck.JumpE <= 1'b0;
            mck.ForwardAE <= '0; 
            mck.ForwardBE <= '0;
            mck.Rs1E <= zero; 
            mck.RdE <= zero;
            mck.RegWriteE <= 1'b0; 
            mck.CsrAccessE <= 1'b0;
            mck.CsrOperationE <= csrrw; 
            mck.CsrIndexE <= mstatus;
            mck.SelectorE <= ALUToReg;
            mck.ALUSrcE <= 1'b0; 
            mck.MemWriteE <= 1'b0;
            mck.MRetE <= 1'b0; 
            mck.EcallE <= 1'b0; 
            mck.EbreakE <= 1'b0; 
            mck.IllegaleInstructionE <= 1'b0;
            mck.TimerInterrupt <= 1'b0; 
            mck.ExternalInterrupt <= 1'b0; 
            mck.SoftwareInterrupt <= 1'b0;
            mck.RdFE <= f0; 
            mck.RD1FE <= '0; 
            mck.RD2FE <= '0;
            mck.FPUControlE <= NOOPERATION; 
            mck.RoundModeE <= RNE;
            mck.FPURegWriteE <= 1'b0; 
            mck.FPUValidE <= 1'b0;
            mck.MoveOperationE <= FPUToFPU; 
            mck.FPUOutW <= '0;
            mck.ForwardFloatingAE <= '0; 
            mck.ForwardFloatingBE <= '0;
            mck.Rs1FE <= f0; 
            mck.Rs2FE <= f0;
        end
    endtask:drv2intf

    task intf2mon (execute_item mon);
        @(pck);
        mon.rst                 = pck.rst;
        mon.RD1E                = pck.RD1E;
        mon.RD2E                = pck.RD2E;
        mon.SignImmE            = pck.SignImmE;
        mon.ResultW             = pck.ResultW;
        mon.PCPlus4E            = pck.PCPlus4E;
        mon.ALUControlE         = pck.ALUControlE;
        mon.funct3E             = pck.funct3E;
        mon.BranchE             = pck.BranchE;
        mon.JumpE               = pck.JumpE;
        mon.ForwardAE           = pck.ForwardAE;
        mon.ForwardBE           = pck.ForwardBE;
        mon.Rs1E                = pck.Rs1E;
        mon.RdE                 = pck.RdE;
        mon.RegWriteE           = pck.RegWriteE;
        mon.CsrAccessE          = pck.CsrAccessE;
        mon.CsrOperationE       = pck.CsrOperationE;
        mon.CsrIndexE           = pck.CsrIndexE;
        mon.SelectorE           = pck.SelectorE;
        mon.ALUSrcE             = pck.ALUSrcE;
        mon.MemWriteE           = pck.MemWriteE;
        mon.MRetE               = pck.MRetE;
        mon.EcallE              = pck.EcallE;
        mon.EbreakE             = pck.EbreakE;
        mon.IllegaleInstructionE= pck.IllegaleInstructionE;
        mon.TimerInterrupt      = pck.TimerInterrupt;
        mon.SoftwareInterrupt   = pck.SoftwareInterrupt;
        mon.ExternalInterrupt   = pck.ExternalInterrupt;
        mon.RdFE                = pck.RdFE;
        mon.RD1FE               = pck.RD1FE;
        mon.RD2FE               = pck.RD2FE;
        mon.FPUControlE         = pck.FPUControlE;
        mon.RoundModeE          = pck.RoundModeE;
        mon.FPURegWriteE        = pck.FPURegWriteE;
        mon.FPUValidE           = pck.FPUValidE;
        mon.MoveOperationE      = pck.MoveOperationE;
        mon.FPUOutW             = pck.FPUOutW;
        mon.ForwardFloatingAE   = pck.ForwardFloatingAE;
        mon.ForwardFloatingBE   = pck.ForwardFloatingBE;
        mon.Rs1FE               = pck.Rs1FE;
        mon.Rs2FE               = pck.Rs2FE;
        mon.ALUOutM             = pck.ALUOutM;
        mon.WriteDataM          = pck.WriteDataM;
        mon.RdM                 = pck.RdM;
        mon.PCSrcE              = pck.PCSrcE;
        mon.RegWriteM           = pck.RegWriteM;
        mon.PCPlus4M            = pck.PCPlus4M;
        mon.SelectorM           = pck.SelectorM;
        mon.funct3M             = pck.funct3M;
        mon.CsrOutM             = pck.CsrOutM;
        mon.MemWriteM           = pck.MemWriteM;
        mon.TrapIsSet           = pck.TrapIsSet;
        mon.CsrOutPC            = pck.CsrOutPC;
        mon.RdFM                = pck.RdFM;
        mon.OverflowM           = pck.OverflowM;
        mon.UnderflowM          = pck.UnderflowM;
        mon.NaNM                = pck.NaNM;
        mon.InfM                = pck.InfM;
        mon.ZeroM               = pck.ZeroM;
        mon.InvalidDivM         = pck.InvalidDivM;
        mon.FPUOutM             = pck.FPUOutM;
        mon.FPURegWriteM        = pck.FPURegWriteM;
        mon.MoveOperationM      = pck.MoveOperationM;
        mon.FPUBusyM            = pck.FPUBusyM;
        mon.FPUDoneM            = pck.FPUDoneM;
    endtask:intf2mon

    modport RISC (clocking pck);

endinterface: execute_interface
