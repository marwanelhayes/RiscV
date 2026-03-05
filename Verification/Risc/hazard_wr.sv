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
    input   logic TrapIsSet,
    input   move_operation_t MoveOperationE,
    input   fpr_t RdFM,
    input   fpr_t RdFW,
    input   fpr_t Rs1FE,
    input   fpr_t Rs2FE,
    input   logic FPURegWriteM,
    input   logic FPURegWriteW,
    
    input  logic [2:0] ForwardAE,
    input  logic [2:0] ForwardBE,
    input  logic StallD,
    input  logic StallF,
    input  logic FlushE,
    input  logic FlushD,
    input  logic [1:0] ForwardFloatingAE,
    input  logic [1:0] ForwardFloatingBE 
);

    bit clk;


    always_comb
    begin
        hazard_intf.Rs1E =Rs1E; 
        hazard_intf.Rs2E =Rs2E; 
        hazard_intf.RdE =RdE; 
        hazard_intf.Rs1D =Rs1D;  
        hazard_intf.Rs2D =Rs2D;  
        hazard_intf.RdM =RdM; 
        hazard_intf.RdW =RdW; 
        hazard_intf.RegWriteM =RegWriteM; 
        hazard_intf.RegWriteW =RegWriteW; 
        hazard_intf.SelectorE =SelectorE; 
        hazard_intf.PCSrcE =PCSrcE;  
        hazard_intf.TrapIsSet = TrapIsSet;
        hazard_intf.MoveOperationE = MoveOperationE;
        hazard_intf.RdFM = RdFM;
        hazard_intf.RdFW = RdFW;
        hazard_intf.Rs1FE = Rs1FE;
        hazard_intf.Rs2FE = Rs2FE;
        hazard_intf.FPURegWriteM = FPURegWriteM;
        hazard_intf.FPURegWriteW = FPURegWriteW;
    
        hazard_intf.ForwardAE = ForwardAE;
        hazard_intf.ForwardBE = ForwardBE;
        hazard_intf.StallD = StallD;
        hazard_intf.StallF = StallF;
        hazard_intf.FlushE = FlushE;
        hazard_intf.FlushD = FlushD;  
        hazard_intf.ForwardFloatingAE = ForwardFloatingAE;
        hazard_intf.ForwardFloatingBE = ForwardFloatingBE;
    end
    /*

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
    assign   hazard_intf.TrapIsSet = TrapIsSet;
    assign   hazard_intf.MoveOperationE = MoveOperationE;
    assign   hazard_intf.RdFM = RdFM;
    assign   hazard_intf.RdFW = RdFW;
    assign   hazard_intf.Rs1FE = Rs1FE;
    assign   hazard_intf.Rs2FE = Rs2FE;
    assign   hazard_intf.FPURegWriteM = FPURegWriteM;
    assign   hazard_intf.FPURegWriteW = FPURegWriteW;
    
    assign   hazard_intf.ForwardAE = ForwardAE;
    assign   hazard_intf.ForwardBE = ForwardBE;
    assign   hazard_intf.StallD = StallD;
    assign   hazard_intf.StallF = StallF;
    assign   hazard_intf.FlushE = FlushE;
    assign   hazard_intf.FlushD = FlushD;  
    assign   hazard_intf.ForwardFloatingAE = ForwardFloatingAE;
    assign   hazard_intf.ForwardFloatingBE = ForwardFloatingBE;
    */
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