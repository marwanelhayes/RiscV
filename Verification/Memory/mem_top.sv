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

    // +MEM_FENCEI: a non-memory item with ALUOutM[4:0] == 0 also acts as a
    // FENCE.I, so the D-cache flush runs (default off). The I-cache
    // invalidate it then requests is acknowledged one cycle later.
    bit   fencei_en;
    logic FenceIM, FenceIBusyM, InvalidateAll, InvalidateDone;
    initial fencei_en = $test$plusargs("MEM_FENCEI");
    assign FenceIM = fencei_en && !intf.MemReadM && !intf.MemWriteM && !intf.AmoM &&
                     (intf.ALUOutM[4:0] == 5'd0);
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
        .ValidM(intf.ValidM),
        .FenceIM(FenceIM),
        .CPUInvalidateDone(InvalidateDone),
        .CPUInvalidateAll(InvalidateAll),
        .FenceIBusyM(FenceIBusyM),
        .FenceIRestartM(),
        .ALUOutM(intf.ALUOutM),
        .WriteDataM(intf.WriteDataM),
        .PCPlus4M(intf.PCPlus4M),
        .RdM(intf.RdM),
        .funct3M(intf.funct3M),
        .RegWriteM(intf.RegWriteM),
        .CsrOutM(intf.CsrOutM),
        .SelectorM(intf.SelectorM),
        .MemWriteM(intf.MemWriteM),
        .MemReadM(intf.MemReadM),
        .AmoM(intf.AmoM),
        .AmoOpM(intf.AmoOpM),
        .StallW(intf.StallW),
        .ValidW(intf.ValidW),
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
    // +AXI_STALL_PCT / +AXI_BRESP_ERR_PCT: back-pressure and write-response
    // errors between the D-cache and the data memory (transparent by default).
    axi_interface #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) ram_bus (clk);
    axi_random_stall #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) DataStalls
    (
        .clk(clk),
        .m_MAWAddr(axi_intf.MAWAddr), .s_MAWAddr(ram_bus.MAWAddr),
        .m_MAWLen(axi_intf.MAWLen), .s_MAWLen(ram_bus.MAWLen),
        .m_MAWSize(axi_intf.MAWSize), .s_MAWSize(ram_bus.MAWSize),
        .m_MAWBurst(axi_intf.MAWBurst), .s_MAWBurst(ram_bus.MAWBurst),
        .m_MAWValid(axi_intf.MAWValid), .s_MAWValid(ram_bus.MAWValid),
        .m_MAWReady(axi_intf.MAWReady), .s_MAWReady(ram_bus.MAWReady),
        .m_MWData(axi_intf.MWData), .s_MWData(ram_bus.MWData),
        .m_MWStrb(axi_intf.MWStrb), .s_MWStrb(ram_bus.MWStrb),
        .m_MWLast(axi_intf.MWLast), .s_MWLast(ram_bus.MWLast),
        .m_MWValid(axi_intf.MWValid), .s_MWValid(ram_bus.MWValid),
        .m_MWReady(axi_intf.MWReady), .s_MWReady(ram_bus.MWReady),
        .m_MBReady(axi_intf.MBReady), .s_MBReady(ram_bus.MBReady),
        .m_MBResp(axi_intf.MBResp), .s_MBResp(ram_bus.MBResp),
        .m_MBValid(axi_intf.MBValid), .s_MBValid(ram_bus.MBValid),
        .m_MARAddr(axi_intf.MARAddr), .s_MARAddr(ram_bus.MARAddr),
        .m_MARLen(axi_intf.MARLen), .s_MARLen(ram_bus.MARLen),
        .m_MARSize(axi_intf.MARSize), .s_MARSize(ram_bus.MARSize),
        .m_MARBurst(axi_intf.MARBurst), .s_MARBurst(ram_bus.MARBurst),
        .m_MARValid(axi_intf.MARValid), .s_MARValid(ram_bus.MARValid),
        .m_MARReady(axi_intf.MARReady), .s_MARReady(ram_bus.MARReady),
        .m_MRReady(axi_intf.MRReady), .s_MRReady(ram_bus.MRReady),
        .m_MRRData(axi_intf.MRRData), .s_MRRData(ram_bus.MRRData),
        .m_MRRResp(axi_intf.MRRResp), .s_MRRResp(ram_bus.MRRResp),
        .m_MRRLast(axi_intf.MRRLast), .s_MRRLast(ram_bus.MRRLast),
        .m_MRRValid(axi_intf.MRRValid), .s_MRRValid(ram_bus.MRRValid)
    );

    risc_data_memory #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) DataMem
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .MAWAddr(ram_bus.MAWAddr),
        .MAWLen(ram_bus.MAWLen),
        .MAWSize(ram_bus.MAWSize),
        .MAWBurst(ram_bus.MAWBurst),
        .MAWValid(ram_bus.MAWValid),
        .MAWReady(ram_bus.MAWReady),
        .MWData(ram_bus.MWData),
        .MWStrb(ram_bus.MWStrb),
        .MWLast(ram_bus.MWLast),
        .MWValid(ram_bus.MWValid),
        .MWReady(ram_bus.MWReady),
        .MBReady(ram_bus.MBReady),
        .MBResp(ram_bus.MBResp),
        .MBValid(ram_bus.MBValid),
        .MARAddr(ram_bus.MARAddr),
        .MARLen(ram_bus.MARLen),
        .MARSize(ram_bus.MARSize),
        .MARBurst(ram_bus.MARBurst),
        .MARValid(ram_bus.MARValid),
        .MARReady(ram_bus.MARReady),
        .MRReady(ram_bus.MRReady),
        .MRRData(ram_bus.MRRData),
        .MRRResp(ram_bus.MRRResp),
        .MRRLast(ram_bus.MRRLast),
        .MRRValid(ram_bus.MRRValid)
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

    bind cache cache_sva #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .TOTAL_LINES(TOTAL_LINES), .WAY(WAY), .LINE_WORDS(LINE_WORDS)) CacheSva (.*);

    // Hazard-unit contract for a stand-alone MEM stage: a D-cache miss
    // freezes the pipeline, so MEM/WB holds until the access completes.
    // ExtraStall stands in for the other freeze source (an I-cache miss): MEM
    // is held although its own access is done, which an SC / AMO* must not
    // repeat.
    bit ExtraStall;
    always @(posedge clk)
        ExtraStall <= ($urandom_range(0, 9) == 0);

    always_comb
    begin
        axi_intf.rst = intf.rst;
        intf.StallW  = !intf.CacheHitM || ExtraStall || FenceIBusyM;
    end

    always_ff @(posedge clk or negedge intf.rst)
        if(!intf.rst) InvalidateDone <= 1'b0;
        else          InvalidateDone <= InvalidateAll;

    // Timing assertions (Verification/<unit>/<unit>_sva.sv)
    bind memory_stage memory_sva MemorySva (.*);

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
            if (test_name != "mem_test" && test_name != "mem_berr_test")
                test_name = "mem_test";
        end

        uvm_config_db #(virtual mem_interface)::set(null,"","INTF",intf);
        uvm_config_db #(virtual axi_interface #(FINAL_DATA_WIDTH, FINAL_ADDR_WIDTH,
            CACHE_AXI_SIZE))::set(null,"","AXI_INTF",axi_intf);
        run_test(test_name);
    end

endmodule
