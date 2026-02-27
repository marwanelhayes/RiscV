module fetch_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "parameters_fetch.svh"

    import fetch_test_pkg::*;

    bit clk;

    localparam CLK_PERIOD = 10;

    fetch_interface #(CLK_PERIOD,`DATA_WIDTH,`ADDR_WIDTH) intf (clk);

    fetch_stage #(`DATA_WIDTH,`ADDR_WIDTH) DUT 
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
        uvm_config_db #(virtual fetch_interface #(CLK_PERIOD,`DATA_WIDTH,`ADDR_WIDTH))::set(null,"","INTF",intf.TEST);
        run_test();
    end

endmodule