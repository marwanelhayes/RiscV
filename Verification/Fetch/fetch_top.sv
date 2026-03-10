module fetch_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
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
        uvm_config_db #(virtual fetch_interface)::set(null,"","INTF",intf.TEST);
        run_test();
    end

endmodule