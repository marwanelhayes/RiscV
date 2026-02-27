import shared_pkg::*;
import mem_item_pkg::*;
interface mem_interface 
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
    logic signed [DATA_WIDTH-1:0] ALUOutM;
    logic signed [DATA_WIDTH-1:0] WriteDataM;
    logic [ADDR_WIDTH-1:0] PCPlus4M;
    gpr_t RdM;
    logic [2:0] funct3M;
    logic RegWriteM;
    logic [DATA_WIDTH-1:0] CsrOutM;
    selector_t SelectorM;
    logic MemWriteM;
    fpr_t RdFM;
    logic OverflowM;
    logic UnderflowM;
    logic NaNM;
    logic InfM;
    logic ZeroM;
    logic InvalidDivM;
    logic [DATA_WIDTH-1:0] FPUOutM;
    move_operation_t MoveOperationM;
    logic FPURegWriteM;
    
    logic signed [DATA_WIDTH-1:0] ReadDataW;
    gpr_t RdW;
    logic RegWriteW;
    selector_t SelectorW;
    logic [ADDR_WIDTH-1:0] PCPlus4W;
    wire [DATA_WIDTH-1:0] CsrOutW;
    logic signed [DATA_WIDTH-1:0] ALUOutW;
    fpr_t RdFW;
    logic OverflowW;
    logic UnderflowW;
    logic NaNW;
    logic InfW;    
    logic ZeroW;
    logic InvalidDivW;
    logic [DATA_WIDTH-1:0] FPUOutW;
    move_operation_t MoveOperationW;
    logic FPURegWriteW;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        //default output #CLK;
        
        input #CLK rst;
        input #CLK ALUOutM;
        input #CLK WriteDataM;
        input #CLK PCPlus4M;
        input #CLK RdM;
        input #CLK funct3M;
        input #CLK RegWriteM;
        input #CLK CsrOutM;
        input #CLK SelectorM;
        input #CLK MemWriteM;
        input #CLK RdFM;
        input #CLK OverflowM;
        input #CLK UnderflowM;
        input #CLK NaNM;
        input #CLK InfM;
        input #CLK ZeroM;
        input #CLK InvalidDivM;
        input #CLK FPUOutM;
        input #CLK MoveOperationM;
        input #CLK FPURegWriteM;

        input ReadDataW;
        input RdW;
        input RegWriteW;
        input SelectorW;
        input PCPlus4W;
        input CsrOutW;
        input ALUOutW;
        input RdFW;
        input OverflowW;
        input UnderflowW;
        input NaNW;
        input InfW;    
        input ZeroW;
        input InvalidDivW;
        input FPUOutW;
        input MoveOperationW;
        input FPURegWriteW;

    endclocking:cb

    task initialize;
        rst = 0;
        ALUOutM <= 0;
        WriteDataM <= 0;
        PCPlus4M <= 0;
        RdM <= zero;
        funct3M <= 0;
        RegWriteM <= 0;
        CsrOutM <= 0;
        SelectorM <= ALUToReg;
        MemWriteM <= 0;
        RdFM <= f0;
        OverflowM <= 0;
        UnderflowM <= 0;
        NaNM <= 0;
        InfM <= 0;
        ZeroM <= 0;
        InvalidDivM <= 0;
        FPUOutM <= 0;
        MoveOperationM <= FPUToFPU;
        FPURegWriteM <= 0;
        
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (mem_item #(DATA_WIDTH,ADDR_WIDTH) drv);
        @(cb);
        rst <= drv.rst;
        ALUOutM <= drv.ALUOutM;
        WriteDataM <= drv.WriteDataM;
        PCPlus4M <= drv.PCPlus4M;
        RdM <= drv.RdM;
        funct3M <= drv.funct3M;
        RegWriteM <= drv.RegWriteM;
        CsrOutM <= drv.CsrOutM;
        SelectorM <= drv.SelectorM;
        MemWriteM <= drv.MemWriteM;
        RdFM <= drv.RdFM;
        OverflowM <= drv.OverflowM;
        UnderflowM <= drv.UnderflowM;
        NaNM <= drv.NaNM;
        InfM <= drv.InfM;
        ZeroM <= drv.ZeroM;
        InvalidDivM <= drv.InvalidDivM;
        FPUOutM <= drv.FPUOutM;
        MoveOperationM <= drv.MoveOperationM;
        FPURegWriteM <= drv.FPURegWriteM;
    endtask:drv2intf


    task intf2mon (mem_item #(DATA_WIDTH,ADDR_WIDTH) mon);
        @(cb);
        mon.rst = cb.rst;
        mon.ALUOutM = cb.ALUOutM;
        mon.WriteDataM = cb.WriteDataM;
        mon.PCPlus4M = cb.PCPlus4M;
        mon.RdM = cb.RdM;
        mon.funct3M = cb.funct3M;
        mon.RegWriteM = cb.RegWriteM;
        mon.CsrOutM = cb.CsrOutM;
        mon.SelectorM = cb.SelectorM;
        mon.MemWriteM = cb.MemWriteM;
        mon.RdFM = cb.RdFM;
        mon.OverflowM = cb.OverflowM;
        mon.UnderflowM = cb.UnderflowM;
        mon.NaNM = cb.NaNM;
        mon.InfM = cb.InfM;
        mon.ZeroM = cb.ZeroM;
        mon.InvalidDivM = cb.InvalidDivM;
        mon.FPUOutM = cb.FPUOutM;
        mon.MoveOperationM = cb.MoveOperationM;
        mon.FPURegWriteM = cb.FPURegWriteM;
        
        mon.ReadDataW = cb.ReadDataW;
        mon.RdW = cb.RdW;
        mon.RegWriteW = cb.RegWriteW;
        mon.SelectorW = cb.SelectorW;
        mon.PCPlus4W = cb.PCPlus4W;
        mon.CsrOutW = cb.CsrOutW;
        mon.ALUOutW = cb.ALUOutW;
        mon.RdFW = cb.RdFW;
        mon.OverflowW = cb.OverflowW;
        mon.UnderflowW = cb.UnderflowW;
        mon.NaNW = cb.NaNW;
        mon.InfW = cb.InfW;
        mon.ZeroW = cb.ZeroW;
        mon.InvalidDivW = cb.InvalidDivW;
        mon.FPUOutW = cb.FPUOutW;
        mon.MoveOperationW = cb.MoveOperationW;
        mon.FPURegWriteW = cb.FPURegWriteW;

    endtask:intf2mon

    modport DUT 
    (
        input clk,
        rst,
        ALUOutM,
        WriteDataM,
        PCPlus4M,
        RdM,
        funct3M,
        RegWriteM,
        CsrOutM,
        SelectorM,
        MemWriteM,
        RdFM,
        OverflowM,
        UnderflowM,
        NaNM,
        InfM,
        ZeroM,
        InvalidDivM,
        FPUOutM,
        MoveOperationM,
        FPURegWriteM,
        output ReadDataW,
        RdW,
        RegWriteW,
        SelectorW,
        PCPlus4W,
        CsrOutW,
        ALUOutW,
        RdFW,
        OverflowW,
        UnderflowW,
        NaNW,
        InfW,
        ZeroW,
        InvalidDivW,
        FPUOutW,
        MoveOperationW,
        FPURegWriteW
    );

    modport TEST (clocking cb); 


endinterface: mem_interface