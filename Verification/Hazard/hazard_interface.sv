import shared_pkg::*;
import hazard_item_pkg::*;
interface hazard_interface 
#(
    parameter int CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
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
    
    wire [2:0] ForwardAE;
    wire [2:0] ForwardBE;
    wire StallD;
    wire StallF;
    wire FlushE;
    wire FlushD;
    wire [1:0] ForwardFloatingAE;
    wire [1:0] ForwardFloatingBE; 

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        default output #CLK;
        
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
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (hazard_item #(DATA_WIDTH,ADDR_WIDTH) drv);
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

    endtask:drv2intf

    task intf2mon (hazard_item #(DATA_WIDTH,ADDR_WIDTH) mon);
        
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