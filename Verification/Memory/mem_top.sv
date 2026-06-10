// =============================================================================
// mem_top.sv
// -----------------------------------------------------------------------------
// Memory stage top-level testbench module for UVM verification.
//
// Connected like fetch_top:
//   - The DUT's AXI4 master (cache refill / write-back) drives a reusable
//     axi_interface and a REAL data_memory AXI slave, so loads and stores are
//     verified end-to-end through the actual cache/AXI path against the
//     memory contents.
//   - AXI_Assertions is bound into the DUT to check the AXI stream protocol.
//   - The *M inputs, *W outputs, and CacheHitM stall response use the
//     transaction-level mem_interface.
// =============================================================================
module mem_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import shared_pkg::*;
    import mem_test_pkg::*;

    bit clk;

    mem_interface intf (clk);
    axi_interface #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) axi_intf (clk);

    memory_stage #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH),
    .CACHE_TOTAL_LINES(CACHE_TOTAL_LINES),
    .CACHE_WAY(CACHE_WAY),
    .CACHE_LINE_WORDS(CACHE_LINE_WORDS),
    .CACHE_READ_ONLY(1'b0),
    .CACHE_AXI_SIZE(CACHE_AXI_SIZE)
    ) DUT
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .ALUOutM(intf.ALUOutM),
        .WriteDataM(intf.WriteDataM),
        .PCPlus4M(intf.PCPlus4M),
        .RdM(intf.RdM),
        .funct3M(intf.funct3M),
        .RegWriteM(intf.RegWriteM),
        .CsrOutM(intf.CsrOutM),
        .SelectorM(intf.SelectorM),
        .MemWriteM(intf.MemWriteM),
        .ReadDataW(intf.ReadDataW),
        .RdW(intf.RdW),
        .RegWriteW(intf.RegWriteW),
        .SelectorW(intf.SelectorW),
        .PCPlus4W(intf.PCPlus4W),
        .CsrOutW(intf.CsrOutW),
        .ALUOutW(intf.ALUOutW),
        .RdFM(intf.RdFM),
        .OverflowM(intf.OverflowM),
        .UnderflowM(intf.UnderflowM),
        .NaNM(intf.NaNM),
        .InfM(intf.InfM),
        .ZeroM(intf.ZeroM),
        .InvalidDivM(intf.InvalidDivM),
        .FPUOutM(intf.FPUOutM),
        .MoveOperationM(intf.MoveOperationM),
        .FPURegWriteM(intf.FPURegWriteM),
        .RdFW(intf.RdFW),
        .OverflowW(intf.OverflowW),
        .UnderflowW(intf.UnderflowW),
        .NaNW(intf.NaNW),
        .InfW(intf.InfW),
        .ZeroW(intf.ZeroW),
        .InvalidDivW(intf.InvalidDivW),
        .FPUOutW(intf.FPUOutW),
        .MoveOperationW(intf.MoveOperationW),
        .FPURegWriteW(intf.FPURegWriteW),
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
        .MRRValid(axi_intf.MRRValid),
        .CacheHitM(intf.CacheHitM)
    );

    // ── Real data memory AXI slave: services cache refills / write-backs so
    //    loads and stores are exercised end-to-end (the predictor's single-
    //    cycle golden is the reference the whole path must match).
    risc_data_memory #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) DataMem
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

    // White-box cache invariants (one-hot hit, no duplicate tags, victim =
    // invalid-first-else-LRU). Replacement/victim correctness lives here, not
    // in the reference model.
    // bind cache cache_sva #(
    //     .DATA_WIDTH (FINAL_DATA_WIDTH),
    //     .ADDR_WIDTH (FINAL_ADDR_WIDTH),
    //     .TOTAL_LINES(CACHE_TOTAL_LINES),
    //     .WAY        (CACHE_WAY),
    //     .LINE_WORDS (CACHE_LINE_WORDS)
    // ) cache_assertions (
    //     .clk(clk),
    //     .rst(rst),
    //     .CPUReadEn(CPUReadEn),
    //     .CPUWriteEn(CPUWriteEn),
    //     .CacheHit(CacheHit),
    //     .hit_array(hit_array),
    //     .valid_reg(valid_reg),
    //     .tags_reg(tags_reg),
    //     .CpuIdx(CpuIdx),
    //     .CpuTag(CpuTag),
    //     .victim_way(victim_way),
    //     .lru_way(lru_way),
    //     .state(state)
    // );

    always_comb
    begin
        axi_intf.rst = intf.rst;
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

        test_name = "mem_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "mem_test")
                test_name = "mem_test";
        end

        uvm_config_db #(virtual mem_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
