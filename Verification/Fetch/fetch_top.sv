// =============================================================================
// fetch_top.sv
// -----------------------------------------------------------------------------
// Fetch stage top-level testbench module for UVM verification.
// =============================================================================
module fetch_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import shared_pkg::*;
    import fetch_test_pkg::*;

    bit clk;

    fetch_interface intf (clk);

    fetch_stage #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .PCF(intf.PCF),
        .StallD(intf.StallD),
        .FlushD(intf.FlushD),
        .PCPlus4D(intf.PCPlus4D),
        .InstructionD(intf.InstructionD),
        .PCPlus4F(intf.PCPlus4F)
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

        test_name = "fetch_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "fetch_test")
                test_name = "fetch_test";
        end

        uvm_config_db #(virtual fetch_interface)::set(null,"","INTF",intf.TEST);
        run_test(test_name);
    end

endmodule
