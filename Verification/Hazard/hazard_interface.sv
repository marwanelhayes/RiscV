import shared_pkg::*;
import hazard_item_pkg::*;
interface hazard_interface  
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    
    gpr_t Rs1E;
    gpr_t Rs2E;
    gpr_t RdE;
    gpr_t Rs1D; 
    gpr_t Rs2D; 
    gpr_t RdM;
    gpr_t RdW;
    logic RegWriteM;
    logic RegWriteW;
    selector_t SelectorE;
    logic PCSrcE;
    logic TrapIsSet;
    move_operation_t MoveOperationE;
    fpr_t RdFM;
    fpr_t RdFW;
    fpr_t Rs1FE;
    fpr_t Rs2FE;
    logic FPURegWriteM;
    logic FPURegWriteW;
    logic FPUValidE;
    logic FPUBusyM;
    logic ICacheHit;
    logic DCacheHit; 
    
    logic [2:0] ForwardAE;
    logic [2:0] ForwardBE;
    logic StallD;
    logic StallF;
    logic FlushE;
    logic FlushD;
    logic [1:0] ForwardFloatingAE;
    logic [1:0] ForwardFloatingBE; 

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking mck @(posedge clk);
        default input #1step output #CLK;
        
        output   Rs1E;
        output   Rs2E;
        output   RdE;
        output   Rs1D; 
        output   Rs2D; 
        output   RdM;
        output   RdW;
        output   RegWriteM;
        output   RegWriteW;
        output   SelectorE;
        output   PCSrcE;
        output   TrapIsSet;
        output   MoveOperationE;
        output   RdFM;
        output   RdFW;
        output   Rs1FE;
        output   Rs2FE;
        output   FPURegWriteM;
        output   FPURegWriteW;
        output   FPUValidE;
        output   FPUBusyM;
        output   ICacheHit;
        output   DCacheHit;

        input  ForwardAE;
        input  ForwardBE;
        input  StallD;
        input  StallF;
        input  FlushE;
        input  FlushD;
        input  ForwardFloatingAE;
        input  ForwardFloatingBE;    
    endclocking:mck

    clocking pck @(posedge clk);
        default input #1step;
        
        input   Rs1E;
        input   Rs2E;
        input   RdE;
        input   Rs1D; 
        input   Rs2D; 
        input   RdM;
        input   RdW;
        input   RegWriteM;
        input   RegWriteW;
        input   SelectorE;
        input   PCSrcE;
        input   TrapIsSet;
        input   MoveOperationE;
        input   RdFM;
        input   RdFW;
        input   Rs1FE;
        input   Rs2FE;
        input   FPURegWriteM;
        input   FPURegWriteW;
        input   FPUValidE;
        input   FPUBusyM;
        input   ICacheHit;
        input   DCacheHit;

        input  ForwardAE;
        input  ForwardBE;
        input  StallD;
        input  StallF;
        input  FlushE;
        input  FlushD;
        input  ForwardFloatingAE;
        input  ForwardFloatingBE;    
    endclocking:pck


    task initialize;
        Rs1E = zero;
        Rs2E = zero;
        RdE = zero;
        Rs1D = zero;
        Rs2D = zero;
        RdM = zero;
        RdW = zero;
        RegWriteM = 0;
        RegWriteW = 0;
        SelectorE = ALUToReg;
        PCSrcE = 0;
        TrapIsSet = 0;
        MoveOperationE = FPUToFPU;
        RdFM = f0;
        RdFW = f0;
        Rs1FE = f0;
        Rs2FE = f0;
        FPURegWriteM = 0;
        FPURegWriteW = 0;
        FPUValidE = 0;
        FPUBusyM = 0;
        ICacheHit = 1;
        DCacheHit = 1;
        repeat(5)
        begin
            @(mck);
        end
    endtask:initialize

    task drv2intf (hazard_item drv);
        @(mck);     
        mck.Rs1E <= drv.Rs1E;
        mck.Rs2E <= drv.Rs2E;
        mck.RdE <= drv.RdE;
        mck.Rs1D <= drv.Rs1D;
        mck.Rs2D <= drv.Rs2D;
        mck.RdM <= drv.RdM;
        mck.RdW <= drv.RdW;
        mck.RegWriteM <= drv.RegWriteM;
        mck.RegWriteW <= drv.RegWriteW;
        mck.SelectorE <= drv.SelectorE;
        mck.PCSrcE <= drv.PCSrcE;
        mck.TrapIsSet <= drv.TrapIsSet;
        mck.MoveOperationE <= drv.MoveOperationE;
        mck.RdFM <= drv.RdFM;
        mck.RdFW <= drv.RdFW;
        mck.Rs1FE <= drv.Rs1FE;
        mck.Rs2FE <= drv.Rs2FE;
        mck.FPURegWriteM <= drv.FPURegWriteM;
        mck.FPURegWriteW <= drv.FPURegWriteW;
        mck.FPUValidE <= drv.FPUValidE;
        mck.FPUBusyM <= drv.FPUBusyM;
        mck.ICacheHit <= drv.ICacheHit;
        mck.DCacheHit <= drv.DCacheHit;
    endtask:drv2intf

    task intf2mon (hazard_item mon);
        @(pck);   
        mon.Rs1E = pck.Rs1E;
        mon.Rs2E = pck.Rs2E;
        mon.RdE = pck.RdE;
        mon.Rs1D = pck.Rs1D;
        mon.Rs2D = pck.Rs2D;
        mon.RdM = pck.RdM;
        mon.RdW = pck.RdW;
        mon.RegWriteM = pck.RegWriteM;
        mon.RegWriteW = pck.RegWriteW;
        mon.SelectorE = pck.SelectorE;
        mon.PCSrcE = pck.PCSrcE;
        mon.TrapIsSet = pck.TrapIsSet;
        mon.ForwardAE = pck.ForwardAE;
        mon.ForwardBE = pck.ForwardBE;
        mon.StallD = pck.StallD;
        mon.StallF = pck.StallF;
        mon.FlushE = pck.FlushE;
        mon.FlushD = pck.FlushD;
        mon.MoveOperationE = pck.MoveOperationE;
        mon.RdFM = pck.RdFM;
        mon.RdFW = pck.RdFW;
        mon.Rs1FE = pck.Rs1FE;
        mon.Rs2FE = pck.Rs2FE;
        mon.ICacheHit = pck.ICacheHit;
        mon.DCacheHit = pck.DCacheHit;
        mon.FPURegWriteM = pck.FPURegWriteM;
        mon.FPURegWriteW = pck.FPURegWriteW;
        mon.ForwardFloatingAE = pck.ForwardFloatingAE;
        mon.ForwardFloatingBE = pck.ForwardFloatingBE;
        mon.FPUValidE = pck.FPUValidE;
        mon.FPUBusyM = pck.FPUBusyM;
    endtask:intf2mon

    modport RISC (clocking pck); 
endinterface: hazard_interface
