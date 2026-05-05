// =============================================================================
// fetch_interface.sv
// -----------------------------------------------------------------------------
// Fetch stage verification interface for RISC-V processor.
//
// Responsibilities:
//   - Provide clocking block for synchronized testbench access
//   - Drive input signals to DUT
//   - Monitor output signals from DUT
//   - Initialize signals to known state
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
    logic StallD;
    logic FlushD;
    
    // ─── DUT output signals ──────────────────────────────────────────────────
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D;
    logic [FINAL_DATA_WIDTH-1:0] InstructionD;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F;

    // ─── Clocking block for testbench ────────────────────────────────────────
    // Note: Input/output direction is relative to testbench, not DUT
    clocking cb @(posedge clk);
        
        default input #0; 
        
        // ── DUT inputs (driven by testbench) ─────────────────────────────────
        input #CLK rst;
        input #CLK PCF;
        input #CLK StallD;
        input #CLK FlushD;

        // ── DUT outputs (monitored by testbench) ─────────────────────────────
        input PCPlus4D;
        input InstructionD;
        input #1step PCPlus4F;    // Delayed to capture previous cycle's value
    
    endclocking:cb


    // ─── Initialization task ────────────────────────────────────────────────
    task initialize;
        rst = 1'b0;
        PCF <= '0;
        StallD <= 1'b0;
        FlushD <= 1'b0;
        
        repeat(5)
        begin
            @(posedge clk);
        end
    endtask:initialize

    // ─── Driver to interface task ────────────────────────────────────────────
    task drv2intf (fetch_item drv);
        @(cb);
        rst <= drv.rst;
        PCF <= drv.PCF;
        StallD <= drv.StallD;
        FlushD <= drv.FlushD;
    endtask:drv2intf

    // ─── Interface to monitor task ──────────────────────────────────────────
    task intf2mon (fetch_item mon);
        @(cb);
        
        mon.rst = cb.rst;
        mon.PCF = cb.PCF;
        mon.StallD = cb.StallD;
        mon.FlushD = cb.FlushD;

        mon.PCPlus4D = cb.PCPlus4D;
        mon.InstructionD = cb.InstructionD;
        mon.PCPlus4F = cb.PCPlus4F;

    endtask:intf2mon

    // ─── DUT modport ─────────────────────────────────────────────────────────
    modport DUT 
    (
        input clk, rst, PCF, StallD, FlushD,
        output PCPlus4D, InstructionD, PCPlus4F
    );

    // ─── Testbench modport ───────────────────────────────────────────────────
    modport TEST (clocking cb); 
endinterface: fetch_interface