// =============================================================================
// risc_interface.sv
// -----------------------------------------------------------------------------
// RISC-V processor verification interface for UVM.
// =============================================================================
import shared_pkg::*;

interface risc_interface  
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    
    logic rst;
    logic ExternalInterrupt;
    logic TimerInterrupt;
    logic SoftwareInterrupt; 

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        default output #CLK;
        output rst;
        output ExternalInterrupt;
        output TimerInterrupt;
        output SoftwareInterrupt;
    endclocking:cb


    task initialize;
        rst = 0;
        ExternalInterrupt = 0;
        TimerInterrupt = 0;
        SoftwareInterrupt = 0;
        repeat(5)
        begin
            @(cb);
        end
        rst = 1;
    endtask:initialize

    modport DUT 
    (
        input clk, rst , ExternalInterrupt , TimerInterrupt , SoftwareInterrupt
    );

    modport TEST (clocking cb); 
endinterface: risc_interface