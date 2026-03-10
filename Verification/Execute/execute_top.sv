module execute_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import execute_test_pkg::*;
    import shared_pkg::*;

    bit clk;

    execute_interface intf (clk);

    execute_stage #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH)) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .RD1E(intf.RD1E),
        .RD2E(intf.RD2E),
        .SignImmE(intf.SignImmE),
        .ResultW(intf.ResultW),
        .PCPlus4E(intf.PCPlus4E),
        .ALUControlE(intf.ALUControlE),
        .funct3E(intf.funct3E),
        .BranchE(intf.BranchE),
        .JumpE(intf.JumpE),
        .ForwardAE(intf.ForwardAE),
        .ForwardBE(intf.ForwardBE),
        .Rs1E(intf.Rs1E),
        .RdE(intf.RdE),
        .RegWriteE(intf.RegWriteE),
        .CsrAccessE(intf.CsrAccessE),
        .CsrOperationE(intf.CsrOperationE),
        .CsrIndexE(intf.CsrIndexE),
        .SelectorE(intf.SelectorE),
        .ALUSrcE(intf.ALUSrcE),
        .MemWriteE(intf.MemWriteE),
        .MRetE(intf.MRetE),
        .EcallE(intf.EcallE),
        .EbreakE(intf.EbreakE),
        .IllegaleInstructionE(intf.IllegaleInstructionE),
        .TimerInterrupt(intf.TimerInterrupt),
        .SoftwareInterrupt(intf.SoftwareInterrupt),
        .ExternalInterrupt(intf.ExternalInterrupt),
        .ALUOutM(intf.ALUOutM),
        .WriteDataM(intf.WriteDataM),
        .RdM(intf.RdM),
        .PCSrcE(intf.PCSrcE),
        .RegWriteM(intf.RegWriteM),
        .PCPlus4M(intf.PCPlus4M),
        .SelectorM(intf.SelectorM),
        .funct3M(intf.funct3M),
        .CsrOutM(intf.CsrOutM),
        .MemWriteM(intf.MemWriteM),
        .TrapIsSet(intf.TrapIsSet),
        .CsrOutPC(intf.CsrOutPC),
        .RdFE(intf.RdFE),
        .RD1FE(intf.RD1FE),
        .RD2FE(intf.RD2FE),
        .FPUControlE(intf.FPUControlE),
        .RoundModeE(intf.RoundModeE),
        .FPURegWriteE(intf.FPURegWriteE),
        .MoveOperationE(intf.MoveOperationE),
        .FPUOutW(intf.FPUOutW),
        .ForwardFloatingAE(intf.ForwardFloatingAE),
        .ForwardFloatingBE(intf.ForwardFloatingBE),
        .Rs1FE(intf.Rs1FE),
        .Rs2FE(intf.Rs2FE),
        .RdFM(intf.RdFM),
        .OverflowM(intf.OverflowM),
        .UnderflowM(intf.UnderflowM),
        .NaNM(intf.NaNM),
        .InfM(intf.InfM),
        .ZeroM(intf.ZeroM),
        .InvalidDivM(intf.InvalidDivM),
        .FPUOutM(intf.FPUOutM),
        .FPURegWriteM(intf.FPURegWriteM),
        .MoveOperationM(intf.MoveOperationM)    
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
        uvm_config_db #(virtual execute_interface)::set(null,"","INTF",intf);
        run_test();
    end

endmodule