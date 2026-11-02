// =============================================================================
// execute_interface.sv
// -----------------------------------------------------------------------------
// Execute verification interface. mck=driver, pck=monitor, RISC=passive view.
//
// The execute stage is checked as a block under the pipeline contract of the
// hazard unit, which execute_top emulates: a random cache freeze
// (MemStallBit) holds EX/MEM and EX; an FP instruction holds EX until the FPU
// is done; a trap squashes the EX instruction (FlushM). While StallE is high
// the driver keeps the EX inputs unchanged, exactly like the ID/EX register.
// =============================================================================
import shared_pkg::*;
import execute_item_pkg::*;

interface execute_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    // ─── DUT input signals ──────────────────────────────────────────────────
    logic rst;
    logic                                    ValidE;
    logic signed [FINAL_DATA_WIDTH-1:0]      RD1E;
    logic signed [FINAL_DATA_WIDTH-1:0]      RD2E;
    logic signed [FINAL_DATA_WIDTH-1:0]      SignImmE;
    logic [FINAL_DATA_WIDTH-1:0]             PCPlus4E;
    logic [FINAL_DATA_WIDTH-1:0]             PCBranchE;
    alu_operation_t                          ALUControlE;
    logic [2:0]                              funct3E;
    logic                                    BranchE;
    logic                                    JumpE;
    logic                                    JalrE;
    logic                                    AuipcE;
    logic                                    WordOpE;
    logic [2:0]                              ForwardAE;
    logic [2:0]                              ForwardBE;
    gpr_t                                    Rs1E;
    gpr_t                                    RdE;
    logic                                    RegWriteE;
    logic                                    CsrAccessE;
    csr_t                                    CsrOperationE;
    csr_index_t                              CsrIndexE;
    selector_t                               SelectorE;
    logic                                    ALUSrcE;
    logic                                    MemWriteE;
    logic                                    MemReadE;
    logic                                    MRetE;
    logic                                    EcallE;
    logic                                    EbreakE;
    logic                                    IllegaleInstructionE;
    fpr_t                                    RdFE;
    logic [FINAL_FLP_WIDTH-1:0]              RD1FE;
    logic [FINAL_FLP_WIDTH-1:0]              RD2FE;
    fpu_operation_t                          FPUControlE;
    round_mode_t                             RoundModeE;
    logic                                    FPURegWriteE;
    logic                                    FPUValidE;
    move_operation_t                         MoveOperationE;
    logic [1:0]                              ForwardFloatingAE;
    logic [1:0]                              ForwardFloatingBE;
    fpr_t                                    Rs1FE;
    fpr_t                                    Rs2FE;
    logic signed [FINAL_DATA_WIDTH-1:0]      ResultW;
    logic [FINAL_FLP_WIDTH-1:0]              FPUOutW;
    logic                                    TimerInterrupt;
    logic                                    ExternalInterrupt;
    logic                                    SoftwareInterrupt;
    logic                                    MemStallBit;

    // ─── Pipeline-contract signals (driven by execute_top) ─────────────────
    logic                                    StallE;
    logic                                    StallM;
    logic                                    FlushM;

    // ─── DUT output signals ─────────────────────────────────────────────────
    logic                                    ValidM;
    logic signed [FINAL_DATA_WIDTH-1:0]      ALUOutM;
    logic signed [FINAL_DATA_WIDTH-1:0]      WriteDataM;
    gpr_t                                    RdM;
    logic                                    PCSrcE;
    logic [FINAL_DATA_WIDTH-1:0]             PCTargetE;
    logic                                    RegWriteM;
    logic [FINAL_DATA_WIDTH-1:0]             PCPlus4M;
    selector_t                               SelectorM;
    logic [2:0]                              funct3M;
    logic [FINAL_DATA_WIDTH-1:0]             CsrOutM;
    logic                                    MemWriteM;
    logic                                    MemReadM;
    logic                                    TrapIsSet;
    logic [FINAL_DATA_WIDTH-1:0]             CsrOutPC;
    fpr_t                                    RdFM;
    logic                                    OverflowM;
    logic                                    UnderflowM;
    logic                                    NaNM;
    logic                                    InfM;
    logic                                    ZeroM;
    logic                                    InvalidDivM;
    logic [FINAL_FLP_WIDTH-1:0]              FPUOutM;
    logic                                    FPURegWriteM;
    move_operation_t                         MoveOperationM;
    logic                                    FPUBusyE;
    logic                                    FPUDoneE;

    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst;
        output ValidE, RD1E, RD2E, SignImmE, PCPlus4E, PCBranchE, ALUControlE, funct3E;
        output BranchE, JumpE, JalrE, AuipcE, WordOpE, ForwardAE, ForwardBE, Rs1E;
        output RdE, RegWriteE, CsrAccessE, CsrOperationE, CsrIndexE, SelectorE, ALUSrcE, MemWriteE;
        output MemReadE, MRetE, EcallE, EbreakE, IllegaleInstructionE, RdFE, RD1FE, RD2FE;
        output FPUControlE, RoundModeE, FPURegWriteE, FPUValidE, MoveOperationE, ForwardFloatingAE, ForwardFloatingBE, Rs1FE;
        output Rs2FE, ResultW, FPUOutW, TimerInterrupt, ExternalInterrupt, SoftwareInterrupt, MemStallBit;
        input  StallE, StallM, FlushM, ValidM, ALUOutM, WriteDataM, RdM, PCSrcE;
        input  PCTargetE, RegWriteM, PCPlus4M, SelectorM, funct3M, CsrOutM, MemWriteM, MemReadM;
        input  TrapIsSet, CsrOutPC, RdFM, OverflowM, UnderflowM, NaNM, InfM, ZeroM;
        input  InvalidDivM, FPUOutM, FPURegWriteM, MoveOperationM, FPUBusyE, FPUDoneE;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;
        input rst;
        input ValidE, RD1E, RD2E, SignImmE, PCPlus4E, PCBranchE, ALUControlE, funct3E;
        input BranchE, JumpE, JalrE, AuipcE, WordOpE, ForwardAE, ForwardBE, Rs1E;
        input RdE, RegWriteE, CsrAccessE, CsrOperationE, CsrIndexE, SelectorE, ALUSrcE, MemWriteE;
        input MemReadE, MRetE, EcallE, EbreakE, IllegaleInstructionE, RdFE, RD1FE, RD2FE;
        input FPUControlE, RoundModeE, FPURegWriteE, FPUValidE, MoveOperationE, ForwardFloatingAE, ForwardFloatingBE, Rs1FE;
        input Rs2FE, ResultW, FPUOutW, TimerInterrupt, ExternalInterrupt, SoftwareInterrupt, MemStallBit, StallE;
        input StallM, FlushM, ValidM, ALUOutM, WriteDataM, RdM, PCSrcE, PCTargetE;
        input RegWriteM, PCPlus4M, SelectorM, funct3M, CsrOutM, MemWriteM, MemReadM, TrapIsSet;
        input CsrOutPC, RdFM, OverflowM, UnderflowM, NaNM, InfM, ZeroM, InvalidDivM;
        input FPUOutM, FPURegWriteM, MoveOperationM, FPUBusyE, FPUDoneE;
    endclocking:pck

    task initialize ();
        rst <= 1'b0;
        ValidE <= 1'b0;
        RD1E <= '0;
        RD2E <= '0;
        SignImmE <= '0;
        PCPlus4E <= '0;
        PCBranchE <= '0;
        ALUControlE <= ADD;
        funct3E <= '0;
        BranchE <= 1'b0;
        JumpE <= 1'b0;
        JalrE <= 1'b0;
        AuipcE <= 1'b0;
        WordOpE <= 1'b0;
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
        MemReadE <= 1'b0;
        MRetE <= 1'b0;
        EcallE <= 1'b0;
        EbreakE <= 1'b0;
        IllegaleInstructionE <= 1'b0;
        RdFE <= f0;
        RD1FE <= '0;
        RD2FE <= '0;
        FPUControlE <= NOOPERATION;
        RoundModeE <= RNE;
        FPURegWriteE <= 1'b0;
        FPUValidE <= 1'b0;
        MoveOperationE <= FPUToFPU;
        ForwardFloatingAE <= '0;
        ForwardFloatingBE <= '0;
        Rs1FE <= f0;
        Rs2FE <= f0;
        ResultW <= '0;
        FPUOutW <= '0;
        TimerInterrupt <= 1'b0;
        ExternalInterrupt <= 1'b0;
        SoftwareInterrupt <= 1'b0;
        MemStallBit <= 1'b0;
        repeat(5) @(posedge clk);
        rst <= 1'b1;
    endtask:initialize

    // EX inputs change only when EX advances (StallE low), like ID/EX; the
    // write-back inputs, interrupt lines and the freeze request change freely.
    task drv2intf (execute_item drv);
        @(mck);
        mck.rst <= drv.rst;
        mck.ResultW <= drv.ResultW;
        mck.FPUOutW <= drv.FPUOutW;
        mck.TimerInterrupt <= drv.TimerInterrupt;
        mck.ExternalInterrupt <= drv.ExternalInterrupt;
        mck.SoftwareInterrupt <= drv.SoftwareInterrupt;
        mck.MemStallBit <= drv.MemStallBit;
        if(!pck.StallE || !pck.rst)
        begin
            mck.ValidE <= drv.ValidE;
            mck.RD1E <= drv.RD1E;
            mck.RD2E <= drv.RD2E;
            mck.SignImmE <= drv.SignImmE;
            mck.PCPlus4E <= drv.PCPlus4E;
            mck.PCBranchE <= drv.PCBranchE;
            mck.ALUControlE <= drv.ALUControlE;
            mck.funct3E <= drv.funct3E;
            mck.BranchE <= drv.BranchE;
            mck.JumpE <= drv.JumpE;
            mck.JalrE <= drv.JalrE;
            mck.AuipcE <= drv.AuipcE;
            mck.WordOpE <= drv.WordOpE;
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
            mck.MemReadE <= drv.MemReadE;
            mck.MRetE <= drv.MRetE;
            mck.EcallE <= drv.EcallE;
            mck.EbreakE <= drv.EbreakE;
            mck.IllegaleInstructionE <= drv.IllegaleInstructionE;
            mck.RdFE <= drv.RdFE;
            mck.RD1FE <= drv.RD1FE;
            mck.RD2FE <= drv.RD2FE;
            mck.FPUControlE <= drv.FPUControlE;
            mck.RoundModeE <= drv.RoundModeE;
            mck.FPURegWriteE <= drv.FPURegWriteE;
            mck.FPUValidE <= drv.FPUValidE;
            mck.MoveOperationE <= drv.MoveOperationE;
            mck.ForwardFloatingAE <= drv.ForwardFloatingAE;
            mck.ForwardFloatingBE <= drv.ForwardFloatingBE;
            mck.Rs1FE <= drv.Rs1FE;
            mck.Rs2FE <= drv.Rs2FE;
        end
    endtask:drv2intf

    task intf2mon (execute_item mon);
        @(pck);
        mon.rst = pck.rst;
        mon.ValidE = pck.ValidE;
        mon.RD1E = pck.RD1E;
        mon.RD2E = pck.RD2E;
        mon.SignImmE = pck.SignImmE;
        mon.PCPlus4E = pck.PCPlus4E;
        mon.PCBranchE = pck.PCBranchE;
        mon.ALUControlE = pck.ALUControlE;
        mon.funct3E = pck.funct3E;
        mon.BranchE = pck.BranchE;
        mon.JumpE = pck.JumpE;
        mon.JalrE = pck.JalrE;
        mon.AuipcE = pck.AuipcE;
        mon.WordOpE = pck.WordOpE;
        mon.ForwardAE = pck.ForwardAE;
        mon.ForwardBE = pck.ForwardBE;
        mon.Rs1E = pck.Rs1E;
        mon.RdE = pck.RdE;
        mon.RegWriteE = pck.RegWriteE;
        mon.CsrAccessE = pck.CsrAccessE;
        mon.CsrOperationE = pck.CsrOperationE;
        mon.CsrIndexE = pck.CsrIndexE;
        mon.SelectorE = pck.SelectorE;
        mon.ALUSrcE = pck.ALUSrcE;
        mon.MemWriteE = pck.MemWriteE;
        mon.MemReadE = pck.MemReadE;
        mon.MRetE = pck.MRetE;
        mon.EcallE = pck.EcallE;
        mon.EbreakE = pck.EbreakE;
        mon.IllegaleInstructionE = pck.IllegaleInstructionE;
        mon.RdFE = pck.RdFE;
        mon.RD1FE = pck.RD1FE;
        mon.RD2FE = pck.RD2FE;
        mon.FPUControlE = pck.FPUControlE;
        mon.RoundModeE = pck.RoundModeE;
        mon.FPURegWriteE = pck.FPURegWriteE;
        mon.FPUValidE = pck.FPUValidE;
        mon.MoveOperationE = pck.MoveOperationE;
        mon.ForwardFloatingAE = pck.ForwardFloatingAE;
        mon.ForwardFloatingBE = pck.ForwardFloatingBE;
        mon.Rs1FE = pck.Rs1FE;
        mon.Rs2FE = pck.Rs2FE;
        mon.ResultW = pck.ResultW;
        mon.FPUOutW = pck.FPUOutW;
        mon.TimerInterrupt = pck.TimerInterrupt;
        mon.ExternalInterrupt = pck.ExternalInterrupt;
        mon.SoftwareInterrupt = pck.SoftwareInterrupt;
        mon.MemStallBit = pck.MemStallBit;
        mon.StallE = pck.StallE;
        mon.StallM = pck.StallM;
        mon.FlushM = pck.FlushM;
        mon.ValidM = pck.ValidM;
        mon.ALUOutM = pck.ALUOutM;
        mon.WriteDataM = pck.WriteDataM;
        mon.RdM = pck.RdM;
        mon.PCSrcE = pck.PCSrcE;
        mon.PCTargetE = pck.PCTargetE;
        mon.RegWriteM = pck.RegWriteM;
        mon.PCPlus4M = pck.PCPlus4M;
        mon.SelectorM = pck.SelectorM;
        mon.funct3M = pck.funct3M;
        mon.CsrOutM = pck.CsrOutM;
        mon.MemWriteM = pck.MemWriteM;
        mon.MemReadM = pck.MemReadM;
        mon.TrapIsSet = pck.TrapIsSet;
        mon.CsrOutPC = pck.CsrOutPC;
        mon.RdFM = pck.RdFM;
        mon.OverflowM = pck.OverflowM;
        mon.UnderflowM = pck.UnderflowM;
        mon.NaNM = pck.NaNM;
        mon.InfM = pck.InfM;
        mon.ZeroM = pck.ZeroM;
        mon.InvalidDivM = pck.InvalidDivM;
        mon.FPUOutM = pck.FPUOutM;
        mon.FPURegWriteM = pck.FPURegWriteM;
        mon.MoveOperationM = pck.MoveOperationM;
        mon.FPUBusyE = pck.FPUBusyE;
        mon.FPUDoneE = pck.FPUDoneE;
    endtask:intf2mon

    modport RISC (clocking pck);

endinterface:execute_interface
