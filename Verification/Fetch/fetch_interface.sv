// =============================================================================
// fetch_interface.sv
// -----------------------------------------------------------------------------
// Fetch stage verification interface for RISC-V processor.
//
// UVM Cookbook compliant structure:
//   - Two clocking blocks (mck = master, pck = passive monitor)
//   - Master outputs use #CLK skew, all inputs use #1step
//   - No modports (per project requirement)
//   - Bus Functional Model (BFM) tasks live in the interface and are invoked
//     from the driver
//   - drv2intf holds PCF on cache miss to mirror writeback-stage stall
//   - FlushD / StallD mutual exclusion is enforced by the sequence item
//     constraints; the BFM also forces StallD on a cache miss
// =============================================================================
import shared_pkg::*;
import fetch_item_pkg::*;

interface fetch_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    // ─── DUT input signals ────────────────────────────────────────────────────
    logic rst;
    logic [FINAL_ADDR_WIDTH-1:0] PCF;
    logic                        StallD;
    logic                        FlushD;

    // ─── DUT output signals ──────────────────────────────────────────────────
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D;
    logic [FINAL_DATA_WIDTH-1:0] InstructionD;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F;
    logic                        CacheHitF;
    logic [FINAL_ADDR_WIDTH-1:0] PCF_delay; // also an output for monitoring

    logic StallBit, FlushBit;

    // ─── Master clocking block (driver view) ─────────────────────────────────
    // Outputs (DUT inputs) use #CLK; inputs (DUT outputs) use #1step.
    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst;
        output PCF;
        output StallBit;
        output FlushBit;
        input  PCPlus4D;
        input  InstructionD;
        input  PCPlus4F;
        input  CacheHitF;
    endclocking:mck

    // ─── Passive clocking block (monitor view) ───────────────────────────────
    // All signals are inputs, sampled with #1step.
    clocking pck @(posedge clk);
        default input #1ns;
        input rst;
        input PCF;
        input StallD;
        input FlushD;
        input PCPlus4D;
        input InstructionD;
        input PCPlus4F;
        input CacheHitF;
    endclocking:pck

    // ─── Initialization task (BFM) ───────────────────────────────────────────
    task initialize;
        rst    <= 1'b0;
        PCF    <= '0;
        StallD <= 1'b0;
        FlushD <= 1'b0;
        PCF_delay <= '0;
        repeat(5) @(posedge clk);
        rst    <= 1'b1;
    endtask:initialize

    // ─── Driver to interface task (BFM) ──────────────────────────────────────
    // Applies the stimulus and honours the cache-miss handshake:
    //   - On a hit, the requested PCF, StallD, and FlushD are issued.
    //   - On a miss, PCF is held (mirrors the writeback-stage stall that
    //     prevents the PC from advancing during a refill) and StallD is
    //     forced high so the IF/ID pipeline register does not advance.
    task drv2intf (fetch_item drv);
        @(mck);
        mck.rst <= drv.rst;
        //mck.PCF <= PCF_delay; // for monitoring the requested PCF regardless of cache hit/miss
        mck.StallBit <= drv.StallD;
        mck.FlushBit <= drv.FlushD;
        if(pck.StallD) // Stall on cache miss or if the sequence item explicitly requests a stall
        begin
            mck.PCF <= PCF;     // hold current PCF
        end
        else
        begin
            mck.PCF <= drv.PCF;
        end
    endtask:drv2intf

    // ─── Interface to monitor task (BFM) ─────────────────────────────────────
    task intf2mon (fetch_item mon);
        @(pck);
        mon.rst          = pck.rst;
        mon.PCF          = pck.PCF;
        mon.StallD       = pck.StallD;
        mon.FlushD       = pck.FlushD;
        mon.PCPlus4D     = pck.PCPlus4D;
        mon.InstructionD = pck.InstructionD;
        mon.PCPlus4F     = pck.PCPlus4F;
        mon.CacheHitF    = pck.CacheHitF;
    endtask:intf2mon

endinterface: fetch_interface
