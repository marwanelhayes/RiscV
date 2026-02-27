module decode_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "parameters_decode.svh"

    import decode_test_pkg::*;

    bit clk;

    localparam CLK_PERIOD = 10;

    decode_interface #(CLK_PERIOD,`DATA_WIDTH,`ADDR_WIDTH) intf (clk);

    decode_stage #(`DATA_WIDTH,`ADDR_WIDTH,2) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .PCPlus4D(intf.PCPlus4D),
        .InstructionD(intf.InstructionD),
        .RdW(intf.RdW),
        .FlushE(intf.FlushE),
        .RegWriteW(intf.RegWriteW),
        .ResultW(intf.ResultW),
        .Rs1E(intf.Rs1E),  
        .Rs2E(intf.Rs2E),
        .Rs1D(intf.Rs1D),
        .Rs2D(intf.Rs2D),
        .RdE(intf.RdE),
        .ALUControlE(intf.ALUControlE),
        .RD1E(intf.RD1E),
        .RD2E(intf.RD2E),
        .SignImmE(intf.SignImmE),
        .PCBranchE(intf.PCBranchE),
        .funct3E(intf.funct3E),
        .RegWriteE(intf.RegWriteE),
        .SelectorE(intf.SelectorE),
        .CsrAccessE(intf.CsrAccessE),
        .CsrIndexE(intf.CsrIndexE),
        .CsrOperationE(intf.CsrOperationE),
        .PCPlus4E(intf.PCPlus4E),
        .MemWriteE(intf.MemWriteE),
        .BranchE(intf.BranchE),
        .ALUSrcE(intf.ALUSrcE),
        .JumpE(intf.JumpE),
        .EcallE(intf.EcallE),
        .EbreakE(intf.EbreakE),
        .MRetE(intf.MRetE),
        .IllegaleInstructionE(intf.IllegaleInstructionE),
        .RdFE(intf.RdFE),
        .RD1FE(intf.RD1FE),
        .RD2FE(intf.RD2FE),
        .FPUControlE(intf.FPUControlE),
        .RoundModeE(intf.RoundModeE),
        .FPURegWriteE(intf.FPURegWriteE),
        .MoveOperationE(intf.MoveOperationE),
        .Rs1FE(intf.Rs1FE),
        .Rs2FE(intf.Rs2FE),
        .FPUOutW(intf.FPUOutW),
        .FPURegWriteW(intf.FPURegWriteW),
        .MoveOperationW(intf.MoveOperationW),
        .RdFW(intf.RdFW)
    );

    initial 
    begin
        clk = 0;
        forever 
        begin
            #(CLK_PERIOD/2) clk = !clk;
        end
    end

    initial
    begin
        uvm_config_db #(virtual decode_interface #(CLK_PERIOD,`DATA_WIDTH,`ADDR_WIDTH))::set(null,"","INTF",intf);
        run_test();
    end

endmodule