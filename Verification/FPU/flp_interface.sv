// =============================================================================
// flp_interface.sv
// -----------------------------------------------------------------------------
// FPU verification interface for the RISC-V processor.
//
// UVM Cookbook compliant structure (mirrors fetch_interface):
//   - Two clocking blocks (mck = master/driver, pck = passive monitor)
//   - Master outputs use #CLK skew, all inputs use #1step
//   - Bus Functional Model (BFM) tasks live in the interface and are invoked
//     from the driver and monitor
//   - "TEST" modport is the verification-side modport passed through the
//     RISC-V top-level verification environment
// =============================================================================
import shared_pkg::*;
import flp_item_pkg::*;

interface flp_interface
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);

    // ─── DUT input signals ────────────────────────────────────────────────────
    logic                            rst;
    logic                            valid;
    logic [FINAL_FLP_WIDTH-1:0]      InA;
    logic [FINAL_FLP_WIDTH-1:0]      InB;
    fpr_t                            RdF;
    logic                            RegWrite;
    round_mode_t                     round_mode;
    fpu_operation_t                  operation;
    move_operation_t                 MoveOperation;

    // ─── DUT output signals ──────────────────────────────────────────────────
    logic                            busy;
    logic                            done;
    logic                            Overflow;
    logic                            Underflow;
    logic                            NaN;
    logic                            Inf;
    logic                            Zero;
    logic                            InvalidDiv;
    logic [FINAL_FLP_WIDTH-1:0]      Result;
    fpr_t                            RdFOut;
    logic                            RegWriteOut;
    move_operation_t                 MoveOperationOut;

    // ─── Master clocking block (driver view) ─────────────────────────────────
    clocking mck @(posedge clk);
        default input #1step output #CLK;
        output rst;
        output valid;
        output InA;
        output InB;
        output RdF;
        output RegWrite;
        output round_mode;
        output operation;
        output MoveOperation;
        input  busy;
        input  done;
        input  Overflow;
        input  Underflow;
        input  NaN;
        input  Inf;
        input  Zero;
        input  InvalidDiv;
        input  Result;
        input  RdFOut;
        input  RegWriteOut;
        input  MoveOperationOut;
    endclocking:mck

    // ─── Passive clocking block (monitor view) ───────────────────────────────
    clocking pck @(posedge clk);
        default input #1step;
        input rst;
        input valid;
        input InA;
        input InB;
        input RdF;
        input RegWrite;
        input round_mode;
        input operation;
        input MoveOperation;
        input busy;
        input done;
        input Overflow;
        input Underflow;
        input NaN;
        input Inf;
        input Zero;
        input InvalidDiv;
        input Result;
        input RdFOut;
        input RegWriteOut;
        input MoveOperationOut;
    endclocking:pck

    // ─── Initialization task (BFM) ───────────────────────────────────────────
    task initialize;
        rst           <= 1'b0;
        valid         <= 1'b0;
        InA           <= '0;
        InB           <= '0;
        RdF           <= f0;
        RegWrite      <= 1'b0;
        round_mode    <= round_mode_t'(0);
        operation     <= fpu_operation_t'(0);
        MoveOperation <= FPUToFPU;
        repeat(5) @(posedge clk);
        mck.rst <= 1'b1;
    endtask:initialize

    // ─── Driver to interface task (BFM) ──────────────────────────────────────
    // Issues stimulus and waits for the multi-cycle done handshake before
    // releasing the sequencer, so the next item does not overrun the FPU.
    task drv2intf (flp_item drv);
        @(mck);
        mck.rst           <= drv.rst;
        mck.valid         <= drv.valid;
        mck.InA           <= drv.InA;
        mck.InB           <= drv.InB;
        mck.RdF           <= drv.RdF;
        mck.RegWrite      <= drv.RegWrite;
        mck.round_mode    <= drv.round_mode;
        mck.operation     <= drv.operation;
        mck.MoveOperation <= drv.MoveOperation;
    endtask:drv2intf

    // ─── Interface to monitor task (BFM) ─────────────────────────────────────
    task intf2mon (flp_item mon);
        @(pck);
        mon.rst              = pck.rst;
        mon.valid            = pck.valid;
        mon.InA              = pck.InA;
        mon.InB              = pck.InB;
        mon.RdF              = pck.RdF;
        mon.RegWrite         = pck.RegWrite;
        mon.round_mode       = pck.round_mode;
        mon.operation        = pck.operation;
        mon.MoveOperation    = pck.MoveOperation;
        mon.busy             = pck.busy;
        mon.done             = pck.done;
        mon.Overflow         = pck.Overflow;
        mon.Underflow        = pck.Underflow;
        mon.NaN              = pck.NaN;
        mon.Inf              = pck.Inf;
        mon.Zero             = pck.Zero;
        mon.InvalidDiv       = pck.InvalidDiv;
        mon.Result           = pck.Result;
        mon.RdFOut           = pck.RdFOut;
        mon.RegWriteOut      = pck.RegWriteOut;
        mon.MoveOperationOut = pck.MoveOperationOut;
    endtask:intf2mon

    function bit checkifvalid (flp_item mon);
        return (mon.valid && !mon.busy && mon.rst);
    endfunction:checkifvalid

    function bit checkifrst (flp_item mon);
        return (!mon.rst);
    endfunction:checkifrst

    function bit checkifdone (flp_item mon);
        return (mon.done && !mon.busy && mon.rst);
    endfunction:checkifdone

    // ─── Verification-side modport ───────────────────────────────────────────
    // "TEST" is the modport passed to the RISC-V top-level verification env.
    modport TEST (clocking pck);

endinterface: flp_interface
