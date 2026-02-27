 import uvm_pkg::*;
`include "uvm_macros.svh"
interface fetch_wr 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] PCF,
    input StallD,
    input FlushD,
    
    input wire [ADDR_WIDTH-1:0] PCPlus4D,
    input wire [DATA_WIDTH-1:0] InstructionD,
    input wire [ADDR_WIDTH-1:0] PCPlus4F
);

    fetch_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) 
    fetch_intf 
    (
        .clk(clk)
    );

    assign fetch_intf.rst = rst;
    assign fetch_intf.PCF = PCF;
    assign fetch_intf.StallD = StallD;
    assign fetch_intf.FlushD = FlushD;

    assign fetch_intf.PCPlus4D = PCPlus4D ;
    assign fetch_intf.InstructionD = InstructionD ;
    assign fetch_intf.PCPlus4F = PCPlus4F ;

    initial
    begin
        uvm_config_db #(virtual fetch_interface #(CLK_PERIOD,DATA_WIDTH,ADDR_WIDTH) )::set(null,"","INTF",fetch_intf.TEST);
    end

endinterface

    