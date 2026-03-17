interface flp_interface 
(
    input bit clk
);
    import shared_pkg::*;
    import flp_item_pkg::*;

    localparam CLK = (CLK_PERIOD/5.0);
    localparam CLK_NECESSARY = (CLK_PERIOD/10.0);
    localparam TIMER = (CLK_PERIOD/7.0);
    localparam SOFTWARE = (CLK_PERIOD/3.5);
    localparam EXTERNAL = (CLK_PERIOD/1.75);


    logic rst;
    logic valid;
    logic [ (FINAL_PRECISION == SINGLE) ? 31 : 63 :0] InA, InB;
    fpr_t RdF;
    logic RegWrite;
    round_mode_t round_mode;
    fpu_operation_t operation;
    logic busy;
    logic done;
    logic Overflow, Underflow, NaN, Inf, Zero,InvalidDiv;
    logic [ (FINAL_PRECISION == SINGLE) ? 31 : 63 :0] Result;
    fpr_t RdFOut;
    logic RegWriteOut;
    move_operation_t MoveOperation;
    move_operation_t MoveOperationOut;

    logic rst_old;
    logic valid_old;
    logic [ (FINAL_PRECISION == SINGLE) ? 31 : 63 :0] InA_old, InB_old;
    fpr_t RdF_old;
    logic RegWrite_old;
    round_mode_t round_mode_old;
    fpu_operation_t operation_old;




    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0 ; 

        input #CLK rst;
        input #CLK valid;
        input #CLK InA;
        input #CLK InB;
        input #CLK RdF;
        input #CLK RegWrite;
        input #CLK round_mode;
        input #CLK operation;
        input #CLK MoveOperation;

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

    endclocking:cb

    task initialize ();
        rst <= 0;
        valid <= 0;
        InA <= 0;
        InB <= 0;
        RdF <= f0;
        RegWrite <= 0;
        round_mode <= round_mode_t'(0);
        operation <= fpu_operation_t'(0);
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (flp_item drv);
        @(cb);
        valid <= drv.valid;
        InA <= drv.InA;
        InB <= drv.InB;
        RdF <= drv.RdF;
        RegWrite <= drv.RegWrite;
        round_mode <= drv.round_mode;
        operation <= drv.operation;
        MoveOperation <= drv.MoveOperation;
        #CLK rst <= 1'b1; //drv.rst;
    endtask:drv2intf

    task intf2mon (flp_item mon);
        fork
            begin
                @(cb);
                mon.rst       = cb.rst;
                mon.valid     = cb.valid;
                mon.InA       = cb.InA;
                mon.InB       = cb.InB;
                mon.RdF       = cb.RdF;
                mon.RegWrite  = cb.RegWrite;
                mon.round_mode = cb.round_mode;
                mon.operation  = cb.operation;
                mon.busy      = cb.busy;
                mon.done      = cb.done;
                mon.Overflow  = cb.Overflow;
                mon.Underflow = cb.Underflow;
                mon.NaN       = cb.NaN;
                mon.Inf       = cb.Inf;
                mon.Zero      = cb.Zero;
                mon.InvalidDiv = cb.InvalidDiv;
                mon.Result    = cb.Result;
                mon.RdFOut    = cb.RdFOut;
                mon.RegWriteOut = cb.RegWriteOut;
                mon.MoveOperation = cb.MoveOperation;
                mon.MoveOperationOut = cb.MoveOperationOut;
                if (cb.valid)
                begin
                    @(cb);
                    while(!cb.done)
                    begin
                        @(cb);
                    end
                    mon.busy      = cb.busy;
                    mon.done      = cb.done;
                    mon.Overflow  = cb.Overflow;
                    mon.Underflow = cb.Underflow;
                    mon.NaN       = cb.NaN;
                    mon.Inf       = cb.Inf;
                    mon.Zero      = cb.Zero;
                    mon.InvalidDiv = cb.InvalidDiv;
                    mon.Result    = cb.Result;
                    mon.RdFOut    = cb.RdFOut;
                    mon.RegWriteOut = cb.RegWriteOut;
                    mon.MoveOperationOut = cb.MoveOperationOut;
                end
            end
            begin
                @(negedge cb.rst);
                mon.rst       = cb.rst;
                mon.valid     = cb.valid;
                mon.InA       = cb.InA;
                mon.InB       = cb.InB;
                mon.RdF       = cb.RdF;
                mon.RegWrite  = cb.RegWrite;
                mon.round_mode = cb.round_mode;
                mon.operation  = cb.operation;
                mon.busy      = cb.busy;
                mon.done      = cb.done;
                mon.Overflow  = cb.Overflow;
                mon.Underflow = cb.Underflow;
                mon.NaN       = cb.NaN;
                mon.Inf       = cb.Inf;
                mon.Zero      = cb.Zero;
                mon.InvalidDiv = cb.InvalidDiv;
                mon.Result    = cb.Result;
                mon.RdFOut    = cb.RdFOut;
                mon.RegWriteOut = cb.RegWriteOut;
                mon.MoveOperation = cb.MoveOperation;
                mon.MoveOperationOut = cb.MoveOperationOut;
            end
        join_any
endtask : intf2mon

    modport DUT 
    (
        input clk,
        rst,
        valid,
        InA,
        InB,
        RdF,
        RegWrite,
        round_mode,
        operation,
        MoveOperation,

        output busy,
        done,
        Overflow,
        Underflow,
        NaN,
        Inf,
        Zero,
        InvalidDiv,
        Result,
        RdFOut,
        RegWriteOut,
        MoveOperationOut
    );

    modport TEST (clocking cb); 
endinterface: flp_interface
