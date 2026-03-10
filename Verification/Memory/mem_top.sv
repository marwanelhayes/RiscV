module mem_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_test_pkg::*;

    bit clk;


    mem_interface intf (clk);

    memory_stage #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .ALUOutM(intf.ALUOutM),
        .WriteDataM(intf.WriteDataM),
        .PCPlus4M(intf.PCPlus4M),
        .RdM(intf.RdM),
        .funct3M(intf.funct3M),
        .RegWriteM(intf.RegWriteM),
        .CsrOutM(intf.CsrOutM),
        .SelectorM(intf.SelectorM),
        .MemWriteM(intf.MemWriteM),
        .ReadDataW(intf.ReadDataW),
        .RdW(intf.RdW),
        .RegWriteW(intf.RegWriteW),
        .SelectorW(intf.SelectorW),
        .PCPlus4W(intf.PCPlus4W),
        .CsrOutW(intf.CsrOutW),
        .ALUOutW(intf.ALUOutW),
        .RdFM(intf.RdFM),
        .OverflowM(intf.OverflowM),
        .UnderflowM(intf.UnderflowM),
        .NaNM(intf.NaNM),
        .InfM(intf.InfM),
        .ZeroM(intf.ZeroM),
        .InvalidDivM(intf.InvalidDivM),
        .FPUOutM(intf.FPUOutM),
        .MoveOperationM(intf.MoveOperationM),
        .FPURegWriteM(intf.FPURegWriteM),
        .RdFW(intf.RdFW),
        .OverflowW(intf.OverflowW),
        .UnderflowW(intf.UnderflowW),
        .NaNW(intf.NaNW),
        .InfW(intf.InfW),
        .ZeroW(intf.ZeroW),
        .InvalidDivW(intf.InvalidDivW),
        .FPUOutW(intf.FPUOutW),
        .MoveOperationW(intf.MoveOperationW),
        .FPURegWriteW(intf.FPURegWriteW)
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
        uvm_config_db #(virtual mem_interface)::set(null,"","INTF",intf);
        run_test();
    end

endmodule