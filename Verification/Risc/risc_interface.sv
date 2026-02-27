import shared_pkg::*;
interface risc_interface 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    
    logic rst;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        default output #CLK;
        output rst;
    endclocking:cb


    task initialize;
        rst = 0;
        repeat(5)
        begin
            @(cb);
        end
        rst = 1;
    endtask:initialize

    modport DUT 
    (
        input clk, rst
    );

    modport TEST (clocking cb); 
endinterface: risc_interface