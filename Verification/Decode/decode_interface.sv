// =============================================================================
// decode_interface.sv
// -----------------------------------------------------------------------------
// Decode verification interface. mck=driver, pck=monitor, TEST=verif modport.
// =============================================================================
import shared_pkg::*;
import decode_item_pkg::*;

interface decode_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    // ─── DUT input signals ──────────────────────────────────────────────────
    logic                                  rst;
    logic [FINAL_DATA_WIDTH-1:0]           PCPlus4D;
    logic [INSTR_WIDTH-1:0]                InstructionD;
    logic                                  ValidD;
    gpr_t                                  RdW;
    logic                                  FlushE;
    logic                                  StallE;
    logic                                  RegWriteW;
    logic signed [FINAL_DATA_WIDTH-1:0]    ResultW;
    fpr_t                                  RdFW;
    logic [FINAL_FLP_WIDTH-1:0]            FPUOutW;
    logic                                  FPURegWriteW;

    // ─── DUT output signals ─────────────────────────────────────────────────
    gpr_t                                  Rs1E, Rs2E, Rs1D, Rs2D, RdE;
    logic                                  ValidE, JumpE, JalrE;
    alu_operation_t                        ALUControlE;
    csr_t                                  CsrOperationE;
    logic signed [FINAL_DATA_WIDTH-1:0]    RD1E, RD2E, SignImmE;
    logic [FINAL_DATA_WIDTH-1:0]           PCBranchE;
    csr_index_t                            CsrIndexE;
    logic [2:0]                            funct3E;
    logic [FINAL_DATA_WIDTH-1:0]           PCPlus4E;
    logic                                  RegWriteE;
    selector_t                             SelectorE;
    logic                                  MemWriteE, MemReadE, BranchE, CsrAccessE, ALUSrcE, AuipcE, WordOpE;
    logic                                  EcallE, EbreakE, MRetE, IllegaleInstructionE;
    fpr_t                                  RdFE;
    logic [FINAL_FLP_WIDTH-1:0]            RD1FE, RD2FE;
    fpu_operation_t                        FPUControlE;
    round_mode_t                           RoundModeE;
    logic                                  FPURegWriteE;
    move_operation_t                       MoveOperationE;
    fpr_t                                  Rs1FE, Rs2FE;
    logic                                  FPUValidE;

    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst, PCPlus4D, InstructionD, ValidD, RdW, FlushE, StallE, RegWriteW, ResultW, RdFW;
        output FPUOutW, FPURegWriteW;
        input  Rs1E, Rs2E, Rs1D, Rs2D, RdE, ValidE, JumpE, JalrE, ALUControlE, CsrOperationE;
        input  RD1E, RD2E, SignImmE, PCBranchE, CsrIndexE, funct3E, PCPlus4E;
        input  RegWriteE, SelectorE, MemWriteE, MemReadE, BranchE, CsrAccessE, ALUSrcE, AuipcE, WordOpE;
        input  EcallE, EbreakE, MRetE, IllegaleInstructionE;
        input  RdFE, RD1FE, RD2FE, FPUControlE, RoundModeE, FPURegWriteE;
        input  MoveOperationE, Rs1FE, Rs2FE, FPUValidE;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;
        input rst, PCPlus4D, InstructionD, ValidD, RdW, FlushE, StallE, RegWriteW, ResultW, RdFW;
        input FPUOutW, FPURegWriteW;
        input Rs1E, Rs2E, Rs1D, Rs2D, RdE, ValidE, JumpE, JalrE, ALUControlE, CsrOperationE;
        input RD1E, RD2E, SignImmE, PCBranchE, CsrIndexE, funct3E, PCPlus4E;
        input RegWriteE, SelectorE, MemWriteE, MemReadE, BranchE, CsrAccessE, ALUSrcE, AuipcE, WordOpE;
        input EcallE, EbreakE, MRetE, IllegaleInstructionE;
        input RdFE, RD1FE, RD2FE, FPUControlE, RoundModeE, FPURegWriteE;
        input MoveOperationE, Rs1FE, Rs2FE, FPUValidE;
    endclocking:pck

    task initialize;
        rst            <= 1'b0;
        PCPlus4D       <= '0;
        InstructionD   <= 32'h0000_0013;
        ValidD         <= 1'b0;
        RdW            <= zero;
        FlushE         <= 1'b0;
        StallE         <= 1'b0;
        RegWriteW      <= 1'b0;
        ResultW        <= '0;
        RdFW           <= f0;
        FPUOutW        <= '0;
        FPURegWriteW   <= 1'b0;
        repeat(5) @(posedge clk);
        rst <= 1'b1;
    endtask:initialize

    task drv2intf (decode_item drv);
        @(mck);
        mck.rst            <= drv.rst;
        mck.PCPlus4D       <= drv.PCPlus4D;
        mck.InstructionD   <= drv.InstructionD;
        mck.ValidD         <= drv.ValidD;
        mck.RdW            <= drv.RdW;
        mck.FlushE         <= drv.FlushE;
        mck.StallE         <= drv.StallE;
        mck.RegWriteW      <= drv.RegWriteW;
        mck.ResultW        <= drv.ResultW;
        mck.RdFW           <= drv.RdFW;
        mck.FPUOutW        <= drv.FPUOutW;
        mck.FPURegWriteW   <= drv.FPURegWriteW;
    endtask:drv2intf

    task intf2mon (decode_item mon);
        @(pck);
        mon.rst                  = pck.rst;
        mon.PCPlus4D             = pck.PCPlus4D;
        mon.InstructionD         = pck.InstructionD;
        mon.ValidD               = pck.ValidD;
        mon.RdW                  = pck.RdW;
        mon.FlushE               = pck.FlushE;
        mon.StallE               = pck.StallE;
        mon.RegWriteW            = pck.RegWriteW;
        mon.ResultW              = pck.ResultW;
        mon.RdFW                 = pck.RdFW;
        mon.FPUOutW              = pck.FPUOutW;
        mon.FPURegWriteW         = pck.FPURegWriteW;
        mon.Rs1E                 = pck.Rs1E;
        mon.Rs2E                 = pck.Rs2E;
        mon.Rs1D                 = pck.Rs1D;
        mon.Rs2D                 = pck.Rs2D;
        mon.RdE                  = pck.RdE;
        mon.ValidE               = pck.ValidE;
        mon.JumpE                = pck.JumpE;
        mon.JalrE                = pck.JalrE;
        mon.ALUControlE          = pck.ALUControlE;
        mon.CsrOperationE        = pck.CsrOperationE;
        mon.RD1E                 = pck.RD1E;
        mon.RD2E                 = pck.RD2E;
        mon.SignImmE             = pck.SignImmE;
        mon.PCBranchE            = pck.PCBranchE;
        mon.CsrIndexE            = pck.CsrIndexE;
        mon.funct3E              = pck.funct3E;
        mon.PCPlus4E             = pck.PCPlus4E;
        mon.RegWriteE            = pck.RegWriteE;
        mon.SelectorE            = pck.SelectorE;
        mon.MemWriteE            = pck.MemWriteE;
        mon.MemReadE             = pck.MemReadE;
        mon.BranchE              = pck.BranchE;
        mon.CsrAccessE           = pck.CsrAccessE;
        mon.ALUSrcE              = pck.ALUSrcE;
        mon.AuipcE               = pck.AuipcE;
        mon.WordOpE              = pck.WordOpE;
        mon.EcallE               = pck.EcallE;
        mon.EbreakE              = pck.EbreakE;
        mon.MRetE                = pck.MRetE;
        mon.IllegaleInstructionE = pck.IllegaleInstructionE;
        mon.RdFE                 = pck.RdFE;
        mon.RD1FE                = pck.RD1FE;
        mon.RD2FE                = pck.RD2FE;
        mon.FPUControlE          = pck.FPUControlE;
        mon.RoundModeE           = pck.RoundModeE;
        mon.FPURegWriteE         = pck.FPURegWriteE;
        mon.MoveOperationE       = pck.MoveOperationE;
        mon.Rs1FE                = pck.Rs1FE;
        mon.Rs2FE                = pck.Rs2FE;
        mon.FPUValidE            = pck.FPUValidE;
    endtask:intf2mon

    modport TEST (clocking mck, clocking pck, output rst);

endinterface: decode_interface
