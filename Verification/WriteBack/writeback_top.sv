// =============================================================================
// writeback_top.sv
// -----------------------------------------------------------------------------
// Write-back stage top-level testbench module for UVM verification.
// =============================================================================
module writeback_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import shared_pkg::*;
    import writeback_test_pkg::*;

    bit clk;

    writeback_interface intf (clk);

    wb_stage #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH) DUT 
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
        string test_name;
        uvm_cmdline_processor clp;

        test_name = "writeback_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "writeback_test")
                test_name = "writeback_test";
        end

        uvm_config_db #(virtual writeback_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
