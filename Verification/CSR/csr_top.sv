// =============================================================================
// csr_top.sv
// -----------------------------------------------------------------------------
// CSR top-level testbench module for UVM verification.
// =============================================================================
module csr_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import csr_test_pkg::*;
    import shared_pkg::*;

    bit clk;

    csr_interface intf (clk);

    csr_file #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH)) DUT
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .CsrOperation(intf.CsrOperation),
        .Rs(intf.Rs),
        .Traps(intf.Traps),
        .mret(intf.mret),
        .PC(intf.PC),
        .Address(intf.Address),
        .CsrAccess(intf.CsrAccess),
        .CsrIn(intf.CsrIn),
        .TimerInterrupt(intf.TimerInterrupt),
        .ExternalInterrupt(intf.ExternalInterrupt),
        .SoftwareInterrupt(intf.SoftwareInterrupt),
        .CsrIndex(intf.CsrIndex),
        .CsrOutPC(intf.CsrOutPC),
        .CsrOut(intf.CsrOut),
        .TrapIsSet(intf.TrapIsSet),
        .RoundingMode(intf.RoundingMode)
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

        test_name = "csr_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "csr_test")
                test_name = "csr_test";
        end

        uvm_config_db #(virtual csr_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
