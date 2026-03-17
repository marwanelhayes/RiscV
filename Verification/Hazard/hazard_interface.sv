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
    
    logic [2:0] ForwardAE;
    logic [2:0] ForwardBE;
    logic StallD;
    logic StallF;
    logic FlushE;
    logic FlushD;
    logic [1:0] ForwardFloatingAE;
    logic [1:0] ForwardFloatingBE; 

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        default output #CLK;
        
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

        input  ForwardAE;
        input  ForwardBE;
        input  StallD;
        input  StallF;
        input  FlushE;
        input  FlushD;
        input  ForwardFloatingAE;
        input  ForwardFloatingBE;    
    endclocking:cb


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
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (hazard_item drv);
        @(cb);
        
        Rs1E <= drv.Rs1E;
        Rs2E <= drv.Rs2E;
        RdE <= drv.RdE;
        Rs1D <= drv.Rs1D;
        Rs2D <= drv.Rs2D;
        RdM <= drv.RdM;
        RdW <= drv.RdW;
        RegWriteM <= drv.RegWriteM;
        RegWriteW <= drv.RegWriteW;
        SelectorE <= drv.SelectorE;
        PCSrcE <= drv.PCSrcE;
        TrapIsSet <= drv.TrapIsSet;
        MoveOperationE <= drv.MoveOperationE;
        RdFM <= drv.RdFM;
        RdFW <= drv.RdFW;
        Rs1FE <= drv.Rs1FE;
        Rs2FE <= drv.Rs2FE;
        FPURegWriteM <= drv.FPURegWriteM;
        FPURegWriteW <= drv.FPURegWriteW;
        FPUValidE <= drv.FPUValidE;
        FPUBusyM <= drv.FPUBusyM;

    endtask:drv2intf

    task intf2mon (hazard_item mon);
        
        @(cb);
        
        mon.Rs1E = Rs1E;
        mon.Rs2E = Rs2E;
        mon.RdE = RdE;
        mon.Rs1D = Rs1D;
        mon.Rs2D = Rs2D;
        mon.RdM = RdM;
        mon.RdW = RdW;
        mon.RegWriteM = RegWriteM;
        mon.RegWriteW = RegWriteW;
        mon.SelectorE = SelectorE;
        mon.PCSrcE = PCSrcE;
        mon.TrapIsSet = TrapIsSet;
        mon.ForwardAE = ForwardAE;
        mon.ForwardBE = ForwardBE;
        mon.StallD = StallD;
        mon.StallF = StallF;
        mon.FlushE = FlushE;
        mon.FlushD = FlushD;
        mon.MoveOperationE = MoveOperationE;
        mon.RdFM = RdFM;
        mon.RdFW = RdFW;
        mon.Rs1FE = Rs1FE;
        mon.Rs2FE = Rs2FE;
        mon.FPURegWriteM = FPURegWriteM;
        mon.FPURegWriteW = FPURegWriteW;
        mon.ForwardFloatingAE = ForwardFloatingAE;
        mon.ForwardFloatingBE = ForwardFloatingBE;
        mon.FPUValidE = FPUValidE;
        mon.FPUBusyM = FPUBusyM;


    endtask:intf2mon

    modport DUT 
    (
        input   Rs1E,
        Rs2E,
        RdE,
        Rs1D, 
        Rs2D, 
        RdM,
        RdW,
        RegWriteM,
        RegWriteW,
        SelectorE,
        PCSrcE,
        TrapIsSet,
        MoveOperationE,
        RdFM,
        RdFW,
        Rs1FE,
        Rs2FE,
        FPURegWriteM,
        FPURegWriteW,
        FPUValidE,
        FPUBusyM, 
        output  ForwardAE, 
        ForwardBE, 
        StallD, 
        StallF, 
        FlushE, 
        FlushD, 
        ForwardFloatingAE, 
        ForwardFloatingBE  
    );

    modport TEST (clocking cb); 
endinterface: hazard_interface
