import shared_pkg::*;
import fetch_item_pkg::*;
interface fetch_interface 
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
    logic [ADDR_WIDTH-1:0] PCF;
    logic StallD;
    logic FlushD;
    
    wire [ADDR_WIDTH-1:0] PCPlus4D;
    wire [DATA_WIDTH-1:0] InstructionD;
    wire [ADDR_WIDTH-1:0] PCPlus4F;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        
        default input #0; 
        //default output #CLK;
        
        input #CLK rst;
        input #CLK PCF;
        input #CLK StallD;
        input #CLK FlushD;

        input PCPlus4D;
        input InstructionD;
        input #1step PCPlus4F; //PCPlus4F is delayed because it should be captured in the active region of the clock cycle or the observed region of the previous clock
    
    endclocking:cb


    task initialize;
        rst = 0;
        PCF <= 0;
        StallD <= 0;
        FlushD <= 0;
        
        repeat(5)
        begin
            @(posedge clk);
        end
    endtask:initialize

    task drv2intf (fetch_item #(DATA_WIDTH,ADDR_WIDTH) drv);
        @(cb);
        rst <= drv.rst;
        PCF <= drv.PCF;
        StallD <= drv.StallD;
        FlushD <= drv.FlushD;
    endtask:drv2intf



    task intf2mon (fetch_item #(DATA_WIDTH,ADDR_WIDTH) mon);
        @(cb);
        
        mon.rst = cb.rst;
        mon.PCF = cb.PCF;
        mon.StallD = cb.StallD;
        mon.FlushD = cb.FlushD;

        mon.PCPlus4D = cb.PCPlus4D;
        mon.InstructionD = cb.InstructionD;
        mon.PCPlus4F = cb.PCPlus4F;

    endtask:intf2mon

    modport DUT 
    (
        input clk, rst, PCF, StallD, FlushD,
        output PCPlus4D, InstructionD, PCPlus4F
    );

    modport TEST (clocking cb); 
endinterface: fetch_interface