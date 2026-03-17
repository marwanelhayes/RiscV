module flp_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import flp_test_pkg::*;
    import shared_pkg::*;

    bit clk;

    flp_interface intf (clk);

    risc_fpu #(.PRECISION(FINAL_PRECISION)) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .valid(intf.valid),
        .InA(intf.InA),
        .InB(intf.InB),
        .RdF(intf.RdF),
        .RegWrite(intf.RegWrite),
        .round_mode(intf.round_mode),
        .operation(intf.operation),
        .busy(intf.busy),
        .done(intf.done),
        .Overflow(intf.Overflow),
        .Underflow(intf.Underflow),
        .NaN(intf.NaN),
        .Inf(intf.Inf),
        .Zero(intf.Zero),
        .InvalidDiv(intf.InvalidDiv),
        .Result(intf.Result),
        .RdFOut(intf.RdFOut),
        .RegWriteOut(intf.RegWriteOut)
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

        test_name = "flp_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "flp_test")
                test_name = "flp_test";
        end

        uvm_config_db #(virtual flp_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
