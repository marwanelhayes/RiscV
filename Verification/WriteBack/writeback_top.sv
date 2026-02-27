module writeback_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "parameters_wb.svh"

    import writeback_test_pkg::*;

    bit clk;

    localparam CLK_PERIOD = 10;

    writeback_interface #(CLK_PERIOD,`DATA_WIDTH,`ADDR_WIDTH) intf (clk);

    wb_stage #(`DATA_WIDTH,`ADDR_WIDTH) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .PCPlus4F(intf.PCPlus4F),
        .PCBranchE(intf.PCBranchE),
        .ALUOutW(intf.ALUOutW),
        .PCSrcE(intf.PCSrcE),
        .StallF(intf.StallF),
        .ReadDataW(intf.ReadDataW),
        .SelectorW(intf.SelectorW),
        .CsrOutW(intf.CsrOutW),
        .PCPlus4W(intf.PCPlus4W),
        .TrapIsSet(intf.TrapIsSet),
        .CsrOutPC(intf.CsrOutPC),
        .ResultW(intf.ResultW),
        .PCF(intf.PCF)
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
        uvm_config_db #(virtual writeback_interface #(CLK_PERIOD,`DATA_WIDTH,`ADDR_WIDTH))::set(null,"","INTF",intf);
        run_test();
    end

endmodule