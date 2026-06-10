// =============================================================================
// mem_interface.sv
// -----------------------------------------------------------------------------
// Memory stage verification interface for RISC-V processor.
//
// The DUT's AXI4 master (cache refill / write-back) is NOT modelled here any
// more - it is driven end-to-end by a real data_memory AXI slave instantiated
// in mem_top, and checked structurally by the bound AXI_Assertions module.
// This interface only carries the *M pipeline inputs, the *W pipeline outputs,
// and the CacheHitM stall response.
//
//   - drv2intf holds the *M inputs on a cache miss (CacheHitM == 0) to mirror
//     the pipeline stall that freezes the MEM stage during a refill.
//   - intf2mon samples the *M inputs, the *W outputs, and CacheHitM so the
//     predictor can gate its single-cycle golden model on the hit response.
// =============================================================================
import shared_pkg::*;
import mem_item_pkg::*;
interface mem_interface
(
    input bit clk
);

    localparam CLK = (CLK_PERIOD/5.0);

    // ─── DUT input signals (*M) ──────────────────────────────────────────────
    logic rst;
    logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM;
    logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4M;
    gpr_t RdM;
    logic [2:0] funct3M;
    logic RegWriteM;
    logic [FINAL_DATA_WIDTH-1:0] CsrOutM;
    selector_t SelectorM;
    logic MemWriteM;
    fpr_t RdFM;
    logic OverflowM;
    logic UnderflowM;
    logic NaNM;
    logic InfM;
    logic ZeroM;
    logic InvalidDivM;
    logic [FINAL_DATA_WIDTH-1:0] FPUOutM;
    move_operation_t MoveOperationM;
    logic FPURegWriteM;

    // ─── Cache hit response (DUT output, drives the stall) ───────────────────
    logic CacheHitM;

    // ─── DUT output signals (*W) ─────────────────────────────────────────────
    logic signed [FINAL_DATA_WIDTH-1:0] ReadDataW;
    gpr_t RdW;
    logic RegWriteW;
    selector_t SelectorW;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4W;
    logic [FINAL_DATA_WIDTH-1:0] CsrOutW;
    logic signed [FINAL_DATA_WIDTH-1:0] ALUOutW;
    fpr_t RdFW;
    logic OverflowW;
    logic UnderflowW;
    logic NaNW;
    logic InfW;
    logic ZeroW;
    logic InvalidDivW;
    logic [FINAL_DATA_WIDTH-1:0] FPUOutW;
    move_operation_t MoveOperationW;
    logic FPURegWriteW;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking mck @(posedge clk);
        default input #1step output #CLK;

        output rst;
        output ALUOutM;
        output WriteDataM;
        output PCPlus4M;
        output RdM;
        output funct3M;
        output RegWriteM;
        output CsrOutM;
        output SelectorM;
        output MemWriteM;
        output RdFM;
        output OverflowM;
        output UnderflowM;
        output NaNM;
        output InfM;
        output ZeroM;
        output InvalidDivM;
        output FPUOutM;
        output MoveOperationM;
        output FPURegWriteM;

        input CacheHitM;
        input ReadDataW;
        input RdW;
        input RegWriteW;
        input SelectorW;
        input PCPlus4W;
        input CsrOutW;
        input ALUOutW;
        input RdFW;
        input OverflowW;
        input UnderflowW;
        input NaNW;
        input InfW;
        input ZeroW;
        input InvalidDivW;
        input FPUOutW;
        input MoveOperationW;
        input FPURegWriteW;
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;

        input rst;
        input ALUOutM;
        input WriteDataM;
        input PCPlus4M;
        input RdM;
        input funct3M;
        input RegWriteM;
        input CsrOutM;
        input SelectorM;
        input MemWriteM;
        input RdFM;
        input OverflowM;
        input UnderflowM;
        input NaNM;
        input InfM;
        input ZeroM;
        input InvalidDivM;
        input FPUOutM;
        input MoveOperationM;
        input FPURegWriteM;

        input CacheHitM;
        input ReadDataW;
        input RdW;
        input RegWriteW;
        input SelectorW;
        input PCPlus4W;
        input CsrOutW;
        input ALUOutW;
        input RdFW;
        input OverflowW;
        input UnderflowW;
        input NaNW;
        input InfW;
        input ZeroW;
        input InvalidDivW;
        input FPUOutW;
        input MoveOperationW;
        input FPURegWriteW;

    endclocking:pck

    task initialize;
        rst = 0;
        ALUOutM <= 0;
        WriteDataM <= 0;
        PCPlus4M <= 0;
        RdM <= zero;
        funct3M <= 0;
        RegWriteM <= 0;
        CsrOutM <= 0;
        SelectorM <= ALUToReg;
        MemWriteM <= 0;
        RdFM <= f0;
        OverflowM <= 0;
        UnderflowM <= 0;
        NaNM <= 0;
        InfM <= 0;
        ZeroM <= 0;
        InvalidDivM <= 0;
        FPUOutM <= 0;
        MoveOperationM <= FPUToFPU;
        FPURegWriteM <= 0;

        repeat(5)
        begin
            @(mck);
        end
        rst = 1;
    endtask:initialize

    // ─── Driver to interface (BFM) ───────────────────────────────────────────
    // Accept fresh stimulus only when the access is not stalled: during reset
    // on a cache hit
    // (CacheHitM == 1) the next request is applied. On a cache miss the *M
    // inputs are HELD so the address/control freeze for the whole refill,
    // exactly like the upstream pipeline stall.
    task drv2intf (mem_item drv);
        @(mck);
        rst <= 1'b1;
        if(pck.CacheHitM)
        begin
            mck.ALUOutM <= drv.ALUOutM;
            mck.WriteDataM <= drv.WriteDataM;
            mck.PCPlus4M <= drv.PCPlus4M;
            mck.RdM <= drv.RdM;
            mck.funct3M <= drv.funct3M;
            mck.RegWriteM <= drv.RegWriteM;
            mck.CsrOutM <= drv.CsrOutM;
            mck.SelectorM <= drv.SelectorM;
            mck.MemWriteM <= drv.MemWriteM;
            mck.RdFM <= drv.RdFM;
            mck.OverflowM <= drv.OverflowM;
            mck.UnderflowM <= drv.UnderflowM;
            mck.NaNM <= drv.NaNM;
            mck.InfM <= drv.InfM;
            mck.ZeroM <= drv.ZeroM;
            mck.InvalidDivM <= drv.InvalidDivM;
            mck.FPUOutM <= drv.FPUOutM;
            mck.MoveOperationM <= drv.MoveOperationM;
            mck.FPURegWriteM <= drv.FPURegWriteM;
        end
        // else: cache miss -> hold *M inputs (pipeline stall during refill)
    endtask:drv2intf


    task intf2mon (mem_item mon);
        @(pck);
        mon.rst = pck.rst;
        mon.ALUOutM = pck.ALUOutM;
        mon.WriteDataM = pck.WriteDataM;
        mon.PCPlus4M = pck.PCPlus4M;
        mon.RdM = pck.RdM;
        mon.funct3M = pck.funct3M;
        mon.RegWriteM = pck.RegWriteM;
        mon.CsrOutM = pck.CsrOutM;
        mon.SelectorM = pck.SelectorM;
        mon.MemWriteM = pck.MemWriteM;
        mon.RdFM = pck.RdFM;
        mon.OverflowM = pck.OverflowM;
        mon.UnderflowM = pck.UnderflowM;
        mon.NaNM = pck.NaNM;
        mon.InfM = pck.InfM;
        mon.ZeroM = pck.ZeroM;
        mon.InvalidDivM = pck.InvalidDivM;
        mon.FPUOutM = pck.FPUOutM;
        mon.MoveOperationM = pck.MoveOperationM;
        mon.FPURegWriteM = pck.FPURegWriteM;

        mon.CacheHitM = pck.CacheHitM;
        mon.ReadDataW = pck.ReadDataW;
        mon.RdW = pck.RdW;
        mon.RegWriteW = pck.RegWriteW;
        mon.SelectorW = pck.SelectorW;
        mon.PCPlus4W = pck.PCPlus4W;
        mon.CsrOutW = pck.CsrOutW;
        mon.ALUOutW = pck.ALUOutW;
        mon.RdFW = pck.RdFW;
        mon.OverflowW = pck.OverflowW;
        mon.UnderflowW = pck.UnderflowW;
        mon.NaNW = pck.NaNW;
        mon.InfW = pck.InfW;
        mon.ZeroW = pck.ZeroW;
        mon.InvalidDivW = pck.InvalidDivW;
        mon.FPUOutW = pck.FPUOutW;
        mon.MoveOperationW = pck.MoveOperationW;
        mon.FPURegWriteW = pck.FPURegWriteW;
    endtask:intf2mon

    modport RISC (clocking pck);
endinterface: mem_interface
