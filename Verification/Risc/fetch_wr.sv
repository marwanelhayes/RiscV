 import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;
interface fetch_wr 
(
    input clk,
    input rst,
    input [FINAL_ADDR_WIDTH-1:0] PCF,
    input StallD,
    input FlushD,
    
    input logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D,
    input logic [FINAL_DATA_WIDTH-1:0] InstructionD,
    input logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F
);

    fetch_interface fetch_intf 
    (
        .clk(clk)
    );
    always_comb 
    begin
        fetch_intf.rst = rst;
        fetch_intf.PCF = PCF;
        fetch_intf.StallD = StallD;
        fetch_intf.FlushD = FlushD;
        fetch_intf.PCPlus4D = PCPlus4D ;
        fetch_intf.InstructionD = InstructionD ;
        fetch_intf.PCPlus4F = PCPlus4F ;
    end

    initial
    begin
        uvm_config_db #(virtual fetch_interface)::set(null,"","INTF",fetch_intf.TEST);
    end

endinterface

    