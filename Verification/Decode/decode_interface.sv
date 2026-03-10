import shared_pkg::*;
import decode_item_pkg::*;
interface decode_interface 
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    
    logic rst;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D;
    logic [FINAL_DATA_WIDTH-1:0] InstructionD;
    gpr_t RdW;
    logic FlushE;
    logic RegWriteW;
    logic signed [FINAL_DATA_WIDTH-1:0] ResultW;
    fpr_t RdFW;
    logic [FINAL_DATA_WIDTH-1:0] FPUOutW;
    move_operation_t MoveOperationW;
    logic FPURegWriteW;
    
    gpr_t Rs1E;
    gpr_t Rs2E;
    gpr_t Rs1D;
    gpr_t Rs2D;
    gpr_t RdE;
    logic JumpE;
    alu_operation_t ALUControlE;
    csr_t CsrOperationE;
    logic signed [FINAL_DATA_WIDTH-1:0] RD1E;
    logic signed [FINAL_DATA_WIDTH-1:0] RD2E;
    logic signed [FINAL_DATA_WIDTH-1:0] SignImmE;
    logic [FINAL_ADDR_WIDTH-1:0] PCBranchE;
    csr_index_t CsrIndexE;
    logic [2:0] funct3E;
    logic [FINAL_ADDR_WIDTH-1:0] PCPlus4E;
    logic RegWriteE ; 
    selector_t SelectorE;
    logic MemWriteE;
    logic BranchE;
    logic CsrAccessE;
    logic ALUSrcE;
    logic EcallE;
    logic EbreakE;
    logic MRetE;
    logic IllegaleInstructionE;
    fpr_t RdFE;
    logic [FINAL_DATA_WIDTH-1:0] RD1FE;
    logic [FINAL_DATA_WIDTH-1:0] RD2FE;
    fpu_operation_t FPUControlE;
    round_mode_t RoundModeE;
    logic FPURegWriteE;
    move_operation_t MoveOperationE;
    fpr_t Rs1FE;
    fpr_t Rs2FE;

    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0; 
        //default output #CLK;
        input #CLK rst;
        input #CLK PCPlus4D;
        input #CLK InstructionD;
        input #CLK RdW;
        input #CLK FlushE;
        input #CLK RegWriteW;
        input #CLK ResultW;
        input #CLK RdFW;
        input #CLK FPUOutW;
        input #CLK MoveOperationW;
        input #CLK FPURegWriteW;
        
        input Rs1E;
        input Rs2E;
        input #1step Rs1D;
        input #1step Rs2D;
        input RdE;
        input JumpE;
        input ALUControlE;
        input CsrOperationE;
        input RD1E;
        input RD2E;
        input SignImmE;
        input PCBranchE;
        input CsrIndexE;
        input funct3E;
        input PCPlus4E;
        input RegWriteE ; 
        input SelectorE;
        input MemWriteE;
        input BranchE;
        input CsrAccessE;
        input ALUSrcE;
        input EcallE;
        input EbreakE;
        input MRetE;
        input IllegaleInstructionE;
        input RdFE;
        input RD1FE;
        input RD2FE;
        input FPUControlE;
        input RoundModeE;
        input FPURegWriteE;
        input MoveOperationE;
        input Rs1FE;
        input Rs2FE;


    endclocking:cb

    task initialize;
        rst = 0;
        PCPlus4D <= 0;
        InstructionD <= 0;
        RdW <= zero;
        FlushE <= 0;
        RegWriteW <= 0;
        ResultW <= 0;
        RdFW <= f0;
        FPUOutW <= 0;
        MoveOperationW <= FPUToFPU;
        FPURegWriteW <= 0;
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (decode_item drv);
        @(cb);
        rst <= drv.rst;
        PCPlus4D <= drv.PCPlus4D;
        InstructionD <= drv.InstructionD;
        RdW <= drv.RdW;
        FlushE <= drv.FlushE;
        RegWriteW <= drv.RegWriteW;
        ResultW <= drv.ResultW;
        RdFW <= drv.RdFW;
        FPUOutW <= drv.FPUOutW;
        MoveOperationW <= drv.MoveOperationW;
        FPURegWriteW <= drv.FPURegWriteW;
    endtask:drv2intf

    task intf2mon (decode_item mon);
        @(cb);
        mon.rst = cb.rst;
        mon.PCPlus4D = cb.PCPlus4D;
        mon.InstructionD = cb.InstructionD;
        mon.RdW = cb.RdW;
        mon.FlushE = cb.FlushE;
        mon.RegWriteW = cb.RegWriteW;
        mon.ResultW = cb.ResultW;
        mon.RdFW = cb.RdFW;
        mon.FPUOutW = cb.FPUOutW;
        mon.MoveOperationW = cb.MoveOperationW;
        mon.FPURegWriteW = cb.FPURegWriteW;
        mon.Rs1E = cb.Rs1E;
        mon.Rs2E = cb.Rs2E;
        mon.Rs1D = cb.Rs1D;
        mon.Rs2D = cb.Rs2D;
        mon.RdE = cb.RdE;
        mon.JumpE = cb.JumpE;
        mon.ALUControlE = cb.ALUControlE;
        mon.CsrOperationE = cb.CsrOperationE;
        mon.RD1E = cb.RD1E;
        mon.RD2E = cb.RD2E;
        mon.SignImmE = cb.SignImmE;
        mon.PCBranchE = cb.PCBranchE;
        mon.CsrIndexE = cb.CsrIndexE;
        mon.funct3E = cb.funct3E;
        mon.PCPlus4E = cb.PCPlus4E;
        mon.RegWriteE = cb.RegWriteE;
        mon.SelectorE = cb.SelectorE;
        mon.MemWriteE = cb.MemWriteE;
        mon.BranchE = cb.BranchE;
        mon.CsrAccessE = cb.CsrAccessE;
        mon.ALUSrcE = cb.ALUSrcE;
        mon.EcallE = cb.EcallE;
        mon.EbreakE = cb.EbreakE;
        mon.MRetE = cb.MRetE;
        mon.IllegaleInstructionE = cb.IllegaleInstructionE;
        mon.RdFE = cb.RdFE; 
        mon.RD1FE = cb.RD1FE; 
        mon.RD2FE = cb.RD2FE; 
        mon.FPUControlE = cb.FPUControlE; 
        mon.RoundModeE = cb.RoundModeE; 
        mon.FPURegWriteE = cb.FPURegWriteE; 
        mon.MoveOperationE = cb.MoveOperationE; 
        mon.Rs1FE = cb.Rs1FE; 
        mon.Rs2FE = cb.Rs2FE; 

    endtask:intf2mon

    modport DUT 
    (
        input clk, rst , PCPlus4D , InstructionD , RdW , FlushE , RegWriteW , ResultW , RdFW , FPUOutW , MoveOperationW , FPURegWriteW , 
        output Rs1E , Rs2E , Rs1D , Rs2D , RdE , JumpE , ALUControlE , CsrOperationE , RD1E , RD2E , SignImmE , PCBranchE , CsrIndexE , funct3E , PCPlus4E , RegWriteE , SelectorE , MemWriteE , BranchE , CsrAccessE , ALUSrcE , EcallE , EbreakE , MRetE , IllegaleInstructionE, RdFE , RD1FE , RD2FE , FPUControlE , RoundModeE , FPURegWriteE , MoveOperationE , Rs1FE , Rs2FE
    );

    modport TEST (clocking cb); 
endinterface: decode_interface