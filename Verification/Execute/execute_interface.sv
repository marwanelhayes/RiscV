import shared_pkg::*;
import execute_item_pkg::*;
interface execute_interface 
#(
    parameter CLK_PERIOD = 10,
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input bit clk
);
    localparam CLK = (CLK_PERIOD/5.0);
    localparam TIMER = (CLK_PERIOD/7.0);
    localparam SOFTWARE = (CLK_PERIOD/3.5);
    localparam EXTERNAL = (CLK_PERIOD/1.75);


    logic rst;
    logic signed [DATA_WIDTH-1:0] RD1E;
    logic signed [DATA_WIDTH-1:0] RD2E;
    logic signed [DATA_WIDTH-1:0] SignImmE;
    logic signed [DATA_WIDTH-1:0] ResultW;
    logic [ADDR_WIDTH-1:0] PCPlus4E;
    alu_operation_t ALUControlE;
    logic [2:0] funct3E;
    logic BranchE;
    logic JumpE;
    logic [2:0] ForwardAE;
    logic [2:0] ForwardBE;
    gpr_t Rs1E;
    gpr_t RdE;
    logic RegWriteE;
    logic CsrAccessE;
    csr_t CsrOperationE;
    csr_index_t CsrIndexE;
    selector_t SelectorE;
    logic ALUSrcE;
    logic MemWriteE;
    logic MRetE;
    logic EcallE;
    logic EbreakE;
    logic IllegaleInstructionE;
    logic TimerInterrupt;
    logic ExternalInterrupt;
    logic SoftwareInterrupt;
    fpr_t RdFE;
    logic [DATA_WIDTH-1:0] RD1FE;
    logic [DATA_WIDTH-1:0] RD2FE;
    fpu_operation_t FPUControlE;
    round_mode_t RoundModeE;
    logic FPURegWriteE;
    move_operation_t MoveOperationE;
    logic [DATA_WIDTH-1:0] FPUOutW;
    logic [1:0] ForwardFloatingAE;
    logic [1:0] ForwardFloatingBE;
    fpr_t Rs1FE;
    fpr_t Rs2FE;


    logic signed [DATA_WIDTH-1:0] ALUOutM;
    logic signed [DATA_WIDTH-1:0] WriteDataM;
    gpr_t RdM;
    logic PCSrcE;
    logic RegWriteM;
    logic [ADDR_WIDTH-1:0] PCPlus4M;
    selector_t SelectorM;
    logic [2:0] funct3M;
    logic [DATA_WIDTH-1:0] CsrOutM;
    logic MemWriteM;
    logic TrapIsSet;
    logic [ADDR_WIDTH-1:0] CsrOutPC;
    fpr_t RdFM;
    logic OverflowM;
    logic UnderflowM;
    logic NaNM;
    logic InfM;
    logic ZeroM;
    logic InvalidDivM;
    logic [DATA_WIDTH-1:0] FPUOutM;
    logic FPURegWriteM;
    move_operation_t MoveOperationM;


    //For clocking block the input output signal direction is with respect to the testbench not the design
    clocking cb @(posedge clk);
        default input #0 ; 

        input #CLK rst;
        input #CLK RD1E;
        input #CLK RD2E;
        input #CLK SignImmE;
        input #CLK ResultW;
        input #CLK PCPlus4E;
        input #CLK ALUControlE;
        input #CLK funct3E;
        input #CLK BranchE;
        input #CLK JumpE;
        input #CLK ForwardAE;
        input #CLK ForwardBE;
        input #CLK Rs1E;
        input #CLK RdE;
        input #CLK RegWriteE;
        input #CLK CsrAccessE;
        input #CLK CsrOperationE;
        input #CLK CsrIndexE;
        input #CLK SelectorE;
        input #CLK ALUSrcE;
        input #CLK MemWriteE;
        input #CLK MRetE;
        input #CLK EcallE;
        input #CLK EbreakE;
        input #CLK IllegaleInstructionE;
        input #CLK TimerInterrupt;
        input #CLK SoftwareInterrupt;
        input #CLK ExternalInterrupt;
        input #CLK RdFE;
        input #CLK RD1FE;
        input #CLK RD2FE;
        input #CLK FPUControlE;
        input #CLK RoundModeE;
        input #CLK FPURegWriteE;
        input #CLK MoveOperationE;
        input #CLK FPUOutW;
        input #CLK ForwardFloatingAE;
        input #CLK ForwardFloatingBE;
        input #CLK Rs1FE;
        input #CLK Rs2FE;

        input ALUOutM;
        input WriteDataM;
        input RdM;
        input #1step PCSrcE;
        input RegWriteM;
        input PCPlus4M;
        input SelectorM;
        input funct3M;
        input CsrOutM;
        input MemWriteM;
        input TrapIsSet;
        input CsrOutPC;
        input RdFM;
        input OverflowM;
        input UnderflowM;
        input NaNM;
        input InfM;
        input ZeroM;
        input InvalidDivM;
        input FPUOutM;
        input FPURegWriteM;
        input MoveOperationM;

    endclocking:cb

    task initialize ();
        rst <= 'b0;
        RD1E <= 'b0;
        RD2E <= 'b0;
        SignImmE <= 'b0;
        ResultW <= 'b0;
        PCPlus4E <= 'b0;
        ALUControlE <= ADD;
        funct3E <= 'b0;
        BranchE <= 'b0;
        JumpE <= 'b0;
        ForwardAE <= 'b0;
        ForwardBE <= 'b0;
        Rs1E <= zero;
        RdE <= zero;
        RegWriteE <= 'b0;
        CsrAccessE <= 'b0;
        CsrOperationE <= csrrw;
        CsrIndexE <= mstatus;
        SelectorE <= ALUToReg;
        ALUSrcE <= 'b0;
        MemWriteE <= 'b0;
        MRetE <= 'b0;
        EcallE <= 'b0;
        EbreakE <= 'b0;
        IllegaleInstructionE <= 'b0;
        TimerInterrupt <= 'b0;
        ExternalInterrupt <= 'b0;
        SoftwareInterrupt <= 'b0;
        RdFE <= f0;
        RD1FE <= RD1FE;
        RD2FE <= RD2FE;
        FPUControlE <= NOOPERATION;
        RoundModeE <= RNE;
        FPURegWriteE <= 'b0;
        MoveOperationE <= FPUToFPU;
        FPUOutW <= 'b0;
        ForwardFloatingAE <= 'b0;
        ForwardFloatingBE <= 'b0;
        Rs1FE <= f0;
        Rs2FE <= f0;
        repeat(5)
        begin
            @(cb);
        end
    endtask:initialize

    task drv2intf (execute_item #(DATA_WIDTH,ADDR_WIDTH) drv);
        @(cb);
        if(!PCSrcE)
        begin
            RD1E <= drv.RD1E;
            RD2E <= drv.RD2E;
            SignImmE <= drv.SignImmE;
            ResultW <= drv.ResultW;
            PCPlus4E <= drv.PCPlus4E;
            ALUControlE <= drv.ALUControlE;
            funct3E <= drv.funct3E;
            BranchE <= drv.BranchE;
            JumpE <= drv.JumpE;
            ForwardAE <= drv.ForwardAE;
            ForwardBE <= drv.ForwardBE;
            Rs1E <= drv.Rs1E;
            RdE <= drv.RdE;
            RegWriteE <= drv.RegWriteE;
            CsrAccessE <= drv.CsrAccessE;
            CsrOperationE <= drv.CsrOperationE;
            CsrIndexE <= drv.CsrIndexE;
            SelectorE <= drv.SelectorE;
            ALUSrcE <= drv.ALUSrcE;
            MemWriteE <= drv.MemWriteE;
            MRetE <= drv.MRetE;
            EcallE <= drv.EcallE;
            EbreakE <= drv.EbreakE;
            IllegaleInstructionE <= drv.IllegaleInstructionE;
            rst <= drv.rst;
            TimerInterrupt <= 1'b0; //drv.TimerInterrupt;
            SoftwareInterrupt <= 1'b0; //drv.SoftwareInterrupt;
            ExternalInterrupt <= 1'b0; //drv.ExternalInterrupt;
            RdFE <= drv.RdFE;
            RD1FE <= drv.RD1FE;
            RD2FE <= drv.RD2FE;
            FPUControlE <= drv.FPUControlE;
            RoundModeE <= drv.RoundModeE;
            FPURegWriteE <= drv.FPURegWriteE;
            MoveOperationE <= drv.MoveOperationE;
            FPUOutW <= drv.FPUOutW;
            ForwardFloatingAE <= drv.ForwardFloatingAE;
            ForwardFloatingBE <= drv.ForwardFloatingBE;
            Rs1FE <= drv.Rs1FE;
            Rs2FE <= drv.Rs2FE;
        end
        else
        begin
            RD1E <= 'b0;
            RD2E <= 'b0;
            SignImmE <= 'b0;
            ResultW <= 'b0;
            PCPlus4E <= 'b0;
            ALUControlE <= ADD;
            funct3E <= 'b0;
            BranchE <= 'b0;
            JumpE <= 'b0;
            ForwardAE <= 'b0;
            ForwardBE <= 'b0;
            Rs1E <= zero;
            RdE <= zero;
            RegWriteE <= 'b0;
            CsrAccessE <= 'b0;
            CsrOperationE <= csrrw;
            CsrIndexE <= mstatus;
            SelectorE <= ALUToReg;
            ALUSrcE <= 'b0;
            MemWriteE <= 'b0;
            MRetE <= 'b0;
            EcallE <= 'b0;
            EbreakE <= 'b0;
            IllegaleInstructionE <= 'b0;
            #CLK rst <= 'b0;
            TimerInterrupt <= 1'b0;
            SoftwareInterrupt <= 1'b0;
            ExternalInterrupt <= 1'b0;
            RdFE <= f0;
            RD1FE <= 0;
            RD2FE <= 0;
            FPUControlE <= NOOPERATION;
            RoundModeE <= RNE;
            FPURegWriteE <= 0;
            MoveOperationE <=FPUToFPU;
            FPUOutW <= 0;
            ForwardFloatingAE <= 0;
            ForwardFloatingBE <= 0;
            Rs1FE <= f0;
            Rs2FE <= f0;
        end
    endtask:drv2intf

    task intf2mon (execute_item #(DATA_WIDTH,ADDR_WIDTH) mon);
        @(cb);
        mon.rst = cb.rst;
        mon.RD1E = cb.RD1E;
        mon.RD2E = cb.RD2E;
        mon.SignImmE = cb.SignImmE;
        mon.ResultW = cb.ResultW;
        mon.PCPlus4E = cb.PCPlus4E;
        mon.ALUControlE = cb.ALUControlE;
        mon.funct3E = cb.funct3E;
        mon.BranchE = cb.BranchE;
        mon.JumpE = cb.JumpE;
        mon.ForwardAE = cb.ForwardAE;
        mon.ForwardBE = cb.ForwardBE;
        mon.Rs1E = cb.Rs1E;
        mon.RdE = cb.RdE;
        mon.RegWriteE = cb.RegWriteE;
        mon.CsrAccessE = cb.CsrAccessE;
        mon.CsrOperationE = cb.CsrOperationE;
        mon.CsrIndexE = cb.CsrIndexE;
        mon.SelectorE = cb.SelectorE;
        mon.ALUSrcE = cb.ALUSrcE;
        mon.MemWriteE = cb.MemWriteE;
        mon.MRetE = cb.MRetE;
        mon.EcallE = cb.EcallE;
        mon.EbreakE = cb.EbreakE;
        mon.IllegaleInstructionE = cb.IllegaleInstructionE;
        mon.TimerInterrupt = cb.TimerInterrupt ;
        mon.SoftwareInterrupt = cb.SoftwareInterrupt ;
        mon.ExternalInterrupt = cb.ExternalInterrupt ;
        mon.RdFE = cb.RdFE;
        mon.RD1FE = cb.RD1FE;
        mon.RD2FE = cb.RD2FE;
        mon.FPUControlE = cb.FPUControlE;
        mon.RoundModeE = cb.RoundModeE;
        mon.FPURegWriteE = cb.FPURegWriteE;
        mon.MoveOperationE = cb.MoveOperationE;
        mon.FPUOutW = cb.FPUOutW;
        mon.ForwardFloatingAE = cb.ForwardFloatingAE;
        mon.ForwardFloatingBE = cb.ForwardFloatingBE;
        mon.Rs1FE = cb.Rs1FE;
        mon.Rs2FE = cb.Rs2FE;
            
        mon.ALUOutM = cb.ALUOutM ;
        mon.WriteDataM = cb.WriteDataM ;
        mon.RdM = cb.RdM ;
        mon.PCSrcE = cb.PCSrcE ;
        mon.RegWriteM = cb.RegWriteM ;
        mon.PCPlus4M = cb.PCPlus4M ;
        mon.SelectorM = cb.SelectorM ;
        mon.funct3M = cb.funct3M ;
        mon.CsrOutM = cb.CsrOutM ;
        mon.MemWriteM = cb.MemWriteM ;
        mon.TrapIsSet = cb.TrapIsSet ;
        mon.CsrOutPC = cb.CsrOutPC ;
        mon.RdFM = cb.RdFM;
        mon.OverflowM = cb.OverflowM;
        mon.UnderflowM = cb.UnderflowM;
        mon.NaNM = cb.NaNM;
        mon.InfM = cb.InfM;
        mon.ZeroM = cb.ZeroM;
        mon.InvalidDivM = cb.InvalidDivM;
        mon.FPUOutM = cb.FPUOutM;
        mon.FPURegWriteM = cb.FPURegWriteM;
        mon.MoveOperationM = cb.MoveOperationM;
    endtask:intf2mon

    modport DUT 
    (
        input clk,
        rst,
        RD1E,
        RD2E,
        SignImmE,
        ResultW,
        PCPlus4E,
        ALUControlE,
        funct3E,
        BranchE,
        JumpE,
        ForwardAE,
        ForwardBE,
        Rs1E,
        RdE,
        RegWriteE,
        CsrAccessE,
        CsrOperationE,
        CsrIndexE,
        SelectorE,
        ALUSrcE,
        MemWriteE,
        MRetE,
        EcallE,
        EbreakE,
        IllegaleInstructionE,
        TimerInterrupt,
        SoftwareInterrupt,
        ExternalInterrupt,
        RdFE,
        RD1FE,
        RD2FE,
        FPUControlE,
        RoundModeE,
        FPURegWriteE,
        MoveOperationE,
        FPUOutW,
        ForwardFloatingAE,
        ForwardFloatingBE,
        Rs1FE,
        Rs2FE,

        output ALUOutM,
        WriteDataM,
        RdM,
        PCSrcE,
        RegWriteM,
        PCPlus4M,
        SelectorM,
        funct3M,
        CsrOutM,
        MemWriteM,
        TrapIsSet,
        CsrOutPC,
        RdFM,
        OverflowM,
        UnderflowM,
        NaNM,
        InfM,
        ZeroM,
        InvalidDivM,
        FPUOutM,
        FPURegWriteM,
        MoveOperationM
    );

    modport TEST (clocking cb); 
endinterface: execute_interface