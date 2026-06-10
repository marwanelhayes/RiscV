// =============================================================================
// hazard_top.sv
// -----------------------------------------------------------------------------
// Hazard unit top-level testbench module for UVM verification.
// =============================================================================
module hazard_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import shared_pkg::*;
    import hazard_test_pkg::*;

    bit clk;

    localparam CLK_PERIOD = 10;

    hazard_interface intf (clk);

    hazard_unit DUT 
    (
    .Rs1E(intf.Rs1E),
    .Rs2E(intf.Rs2E),
    .RdE(intf.RdE),
    .Rs1D(intf.Rs1D), 
    .Rs2D(intf.Rs2D), 
    .RdM(intf.RdM),
    .RdW(intf.RdW),
    .RegWriteM(intf.RegWriteM),
    .RegWriteW(intf.RegWriteW),
    .SelectorE(intf.SelectorE),
    .PCSrcE(intf.PCSrcE), 
    .TrapIsSet(intf.TrapIsSet),
    .ForwardAE(intf.ForwardAE),
    .ForwardBE(intf.ForwardBE),
    .ICacheHit(intf.ICacheHit),
    .DCacheHit(intf.DCacheHit),
    .FPUValidE(intf.FPUValidE),
    .FPUBusyM(intf.FPUBusyM),
    .StallD(intf.StallD),
    .StallF(intf.StallF),
    .FlushE(intf.FlushE),
    .FlushD(intf.FlushD),
    .MoveOperationE(intf.MoveOperationE),
    .RdFM(intf.RdFM),
    .RdFW(intf.RdFW),
    .Rs1FE(intf.Rs1FE),
    .Rs2FE(intf.Rs2FE),
    .FPURegWriteM(intf.FPURegWriteM),
    .FPURegWriteW(intf.FPURegWriteW),
    .ForwardFloatingAE(intf.ForwardFloatingAE),
    .ForwardFloatingBE(intf.ForwardFloatingBE)    
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

        test_name = "hazard_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "hazard_test")
                test_name = "hazard_test";
        end

        uvm_config_db #(virtual hazard_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
