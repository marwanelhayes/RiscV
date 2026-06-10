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
    axi_interface #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) axi_intf (clk);


    fetch_stage #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH),
    .CACHE_TOTAL_LINES(CACHE_TOTAL_LINES),
    .CACHE_WAY(CACHE_WAY),
    .CACHE_LINE_WORDS(CACHE_LINE_WORDS),
    .CACHE_READ_ONLY(1'b1),
    .CACHE_AXI_SIZE(CACHE_AXI_SIZE)
    )  DUT
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .PCF(intf.PCF),
        .StallD(intf.StallD), // Stall on cache miss
        .FlushD(intf.FlushD), // Flush on control hazard
        .PCPlus4D(intf.PCPlus4D),
        .InstructionD(intf.InstructionD),
        .PCPlus4F(intf.PCPlus4F),
        .CacheHitF(intf.CacheHitF),
        .MAWAddr(axi_intf.MAWAddr),
        .MAWLen(axi_intf.MAWLen),
        .MAWSize(axi_intf.MAWSize),
        .MAWBurst(axi_intf.MAWBurst),
        .MAWValid(axi_intf.MAWValid),
        .MAWReady(axi_intf.MAWReady),
        .MWData(axi_intf.MWData),
        .MWStrb(axi_intf.MWStrb),
        .MWLast(axi_intf.MWLast),
        .MWValid(axi_intf.MWValid),
        .MWReady(axi_intf.MWReady),
        .MBReady(axi_intf.MBReady),
        .MBResp(axi_intf.MBResp),
        .MBValid(axi_intf.MBValid),
        .MARAddr(axi_intf.MARAddr),
        .MARLen(axi_intf.MARLen),
        .MARSize(axi_intf.MARSize),
        .MARBurst(axi_intf.MARBurst),
        .MARValid(axi_intf.MARValid),
        .MARReady(axi_intf.MARReady),
        .MRReady(axi_intf.MRReady),
        .MRRData(axi_intf.MRRData),
        .MRRResp(axi_intf.MRRResp),
        .MRRLast(axi_intf.MRRLast),
        .MRRValid(axi_intf.MRRValid)
    );

    risc_instruction_memory #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) InstrMem
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .MAWAddr(axi_intf.MAWAddr),
        .MAWLen(axi_intf.MAWLen),
        .MAWSize(axi_intf.MAWSize),
        .MAWBurst(axi_intf.MAWBurst),
        .MAWValid(axi_intf.MAWValid),
        .MAWReady(axi_intf.MAWReady),
        .MWData(axi_intf.MWData),
        .MWStrb(axi_intf.MWStrb),
        .MWLast(axi_intf.MWLast),
        .MWValid(axi_intf.MWValid),
        .MWReady(axi_intf.MWReady),
        .MBReady(axi_intf.MBReady),
        .MBResp(axi_intf.MBResp),
        .MBValid(axi_intf.MBValid),
        .MARAddr(axi_intf.MARAddr),
        .MARLen(axi_intf.MARLen),
        .MARSize(axi_intf.MARSize),
        .MARBurst(axi_intf.MARBurst),
        .MARValid(axi_intf.MARValid),
        .MARReady(axi_intf.MARReady),
        .MRReady(axi_intf.MRReady),
        .MRRData(axi_intf.MRRData),
        .MRRResp(axi_intf.MRRResp),
        .MRRLast(axi_intf.MRRLast),
        .MRRValid(axi_intf.MRRValid)
    );

    bind DUT AXI_Assertions #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) axi_protocol_assertions(
        .clk(clk),
        .rst(rst),
        .MAWAddr(MAWAddr),
        .MAWLen(MAWLen),
        .MAWSize(MAWSize),
        .MAWBurst(MAWBurst),
        .MAWValid(MAWValid),
        .MAWReady(MAWReady),
        .MWData(MWData),
        .MWStrb(MWStrb),
        .MWLast(MWLast),
        .MWValid(MWValid),
        .MWReady(MWReady),
        .MBReady(MBReady),
        .MBResp(MBResp),
        .MBValid(MBValid),
        .MARAddr(MARAddr),
        .MARLen(MARLen),
        .MARSize(MARSize),
        .MARBurst(MARBurst),
        .MARValid(MARValid),
        .MARReady(MARReady),
        .MRReady(MRReady),
        .MRRData(MRRData),
        .MRRResp(MRRResp),
        .MRRLast(MRRLast),
        .MRRValid(MRRValid)
    );

    always_comb
    begin
        axi_intf.rst = intf.rst;
        intf.StallD = intf.StallBit | (!intf.CacheHitF); // Stall on cache miss or if the sequence item explicitly requests a stall
        intf.FlushD = intf.FlushBit & (!intf.StallD); // Flush on control hazard
    end

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

        uvm_config_db #(virtual fetch_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
