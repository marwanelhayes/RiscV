module hazard_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
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
        uvm_config_db #(virtual hazard_interface)::set(null,"","INTF",intf);
        run_test();
    end

endmodule