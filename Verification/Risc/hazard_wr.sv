import uvm_pkg::*;
`include "uvm_macros.svh"
import shared_pkg::*;

interface hazard_wr 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(   
    input   gpr_t Rs1E,
    input   gpr_t Rs2E,
    input   gpr_t RdE,
    input   gpr_t Rs1D, 
    input   gpr_t Rs2D, 
    input   gpr_t RdM,
    input   gpr_t RdW,
    input   logic RegWriteM,
    input   logic RegWriteW,
    input   selector_t SelectorE,
    input   logic PCSrcE, 
    
    input   logic [1:0] ForwardAE,
    input   logic [1:0] ForwardBE,
    input   logic StallD,
    input   logic StallF,
    input   logic FlushE,
    input   logic FlushD
);

    bit clk;





    assign   hazard_intf.Rs1E =Rs1E; 
    assign   hazard_intf.Rs2E =Rs2E; 
    assign   hazard_intf.RdE =RdE; 
    assign   hazard_intf.Rs1D =Rs1D;  
    assign   hazard_intf.Rs2D =Rs2D;  
    assign   hazard_intf.RdM =RdM; 
    assign   hazard_intf.RdW =RdW; 
    assign   hazard_intf.RegWriteM =RegWriteM; 
    assign   hazard_intf.RegWriteW =RegWriteW; 
    assign   hazard_intf.SelectorE =SelectorE; 
    assign   hazard_intf.PCSrcE =PCSrcE;  
    
    assign   hazard_intf.ForwardAE = ForwardAE;
    assign   hazard_intf.ForwardBE = ForwardBE;
    assign   hazard_intf.StallD = StallD;
    assign   hazard_intf.StallF = StallF;
    assign   hazard_intf.FlushE = FlushE;
    assign   hazard_intf.FlushD = FlushD;  
    
    initial 
    begin
        clk = 0;
        forever 
        begin
            #(CLK_PERIOD/2) clk = !clk;
        end
    end

    hazard_interface #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) hazard_intf (
        .clk(clk)
    );
    
    initial
    begin
        uvm_config_db #(virtual hazard_interface #(.CLK_PERIOD(CLK_PERIOD),.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)))::set(null,"","INTF",hazard_intf.TEST);
    end

endinterface