// =============================================================================
// risc_top.sv
// -----------------------------------------------------------------------------
// RISC-V processor top-level testbench module for UVM verification.
// =============================================================================
module risc_top
#(
    parameter string PROGRAM_DIR = ""   // program image directory: vsim -gPROGRAM_DIR=<dir>
);

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import risc_test_pkg::*;

    bit clk;


    risc_interface intf (clk);
    axi_interface #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) iaxi_intf (clk);
    axi_interface #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) daxi_intf (clk);

    // mtime until the CLINT (B7.3): free-running from an offset that keeps
    // time != mcycle and makes timeh roll over after 256 cycles.
    logic [63:0] MTime;
    always_ff @(posedge clk or negedge intf.rst)
        if(!intf.rst) MTime <= 64'h0000_0000_FFFF_FF00;
        else          MTime <= MTime + 64'd1;


    riscv_processor #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH)) 
    DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .ExternalInterrupt(intf.ExternalInterrupt),
        .TimerInterrupt(intf.TimerInterrupt),
        .SoftwareInterrupt(intf.SoftwareInterrupt),
        .SExternalInterrupt(intf.SExternalInterrupt),
        .MTime(MTime),
        .IMAWAddr(iaxi_intf.MAWAddr),
        .IMAWLen(iaxi_intf.MAWLen),
        .IMAWSize(iaxi_intf.MAWSize),
        .IMAWBurst(iaxi_intf.MAWBurst),
        .IMAWValid(iaxi_intf.MAWValid),
        .IMAWReady(iaxi_intf.MAWReady),
        .IMWData(iaxi_intf.MWData),
        .IMWStrb(iaxi_intf.MWStrb),
        .IMWLast(iaxi_intf.MWLast),
        .IMWValid(iaxi_intf.MWValid),
        .IMWReady(iaxi_intf.MWReady),
        .IMBReady(iaxi_intf.MBReady),
        .IMBResp(iaxi_intf.MBResp),
        .IMBValid(iaxi_intf.MBValid),
        .IMARAddr(iaxi_intf.MARAddr),
        .IMARLen(iaxi_intf.MARLen),
        .IMARSize(iaxi_intf.MARSize),
        .IMARBurst(iaxi_intf.MARBurst),
        .IMARValid(iaxi_intf.MARValid),
        .IMARReady(iaxi_intf.MARReady),
        .IMRReady(iaxi_intf.MRReady),
        .IMRRData(iaxi_intf.MRRData),
        .IMRRResp(iaxi_intf.MRRResp),
        .IMRRLast(iaxi_intf.MRRLast),
        .IMRRValid(iaxi_intf.MRRValid),
        .DMAWAddr(daxi_intf.MAWAddr),
        .DMAWLen(daxi_intf.MAWLen),
        .DMAWSize(daxi_intf.MAWSize),
        .DMAWBurst(daxi_intf.MAWBurst),
        .DMAWValid(daxi_intf.MAWValid),
        .DMAWReady(daxi_intf.MAWReady),
        .DMWData(daxi_intf.MWData),
        .DMWStrb(daxi_intf.MWStrb),
        .DMWLast(daxi_intf.MWLast),
        .DMWValid(daxi_intf.MWValid),
        .DMWReady(daxi_intf.MWReady),
        .DMBReady(daxi_intf.MBReady),
        .DMBResp(daxi_intf.MBResp),
        .DMBValid(daxi_intf.MBValid),
        .DMARAddr(daxi_intf.MARAddr),
        .DMARLen(daxi_intf.MARLen),
        .DMARSize(daxi_intf.MARSize),
        .DMARBurst(daxi_intf.MARBurst),
        .DMARValid(daxi_intf.MARValid),
        .DMARReady(daxi_intf.MARReady),
        .DMRReady(daxi_intf.MRReady),
        .DMRRData(daxi_intf.MRRData),
        .DMRRResp(daxi_intf.MRRResp),
        .DMRRLast(daxi_intf.MRRLast),
        .DMRRValid(daxi_intf.MRRValid)
    );

    // Published to the TB before any initial block runs (variable initializer)
    bit program_dir_set = tb_base_pkg::set_program_dir(PROGRAM_DIR);

    // +AXI_STALL_PCT exercises D-cache write-backs under backpressure.
    axi_interface #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) ram_bus (clk);
    axi_random_stall #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) DataStalls
    (
        .clk(clk),
        .m_MAWAddr(daxi_intf.MAWAddr), .s_MAWAddr(ram_bus.MAWAddr),
        .m_MAWLen(daxi_intf.MAWLen), .s_MAWLen(ram_bus.MAWLen),
        .m_MAWSize(daxi_intf.MAWSize), .s_MAWSize(ram_bus.MAWSize),
        .m_MAWBurst(daxi_intf.MAWBurst), .s_MAWBurst(ram_bus.MAWBurst),
        .m_MAWValid(daxi_intf.MAWValid), .s_MAWValid(ram_bus.MAWValid),
        .m_MAWReady(daxi_intf.MAWReady), .s_MAWReady(ram_bus.MAWReady),
        .m_MWData(daxi_intf.MWData), .s_MWData(ram_bus.MWData),
        .m_MWStrb(daxi_intf.MWStrb), .s_MWStrb(ram_bus.MWStrb),
        .m_MWLast(daxi_intf.MWLast), .s_MWLast(ram_bus.MWLast),
        .m_MWValid(daxi_intf.MWValid), .s_MWValid(ram_bus.MWValid),
        .m_MWReady(daxi_intf.MWReady), .s_MWReady(ram_bus.MWReady),
        .m_MBReady(daxi_intf.MBReady), .s_MBReady(ram_bus.MBReady),
        .m_MBResp(daxi_intf.MBResp), .s_MBResp(ram_bus.MBResp),
        .m_MBValid(daxi_intf.MBValid), .s_MBValid(ram_bus.MBValid),
        .m_MARAddr(daxi_intf.MARAddr), .s_MARAddr(ram_bus.MARAddr),
        .m_MARLen(daxi_intf.MARLen), .s_MARLen(ram_bus.MARLen),
        .m_MARSize(daxi_intf.MARSize), .s_MARSize(ram_bus.MARSize),
        .m_MARBurst(daxi_intf.MARBurst), .s_MARBurst(ram_bus.MARBurst),
        .m_MARValid(daxi_intf.MARValid), .s_MARValid(ram_bus.MARValid),
        .m_MARReady(daxi_intf.MARReady), .s_MARReady(ram_bus.MARReady),
        .m_MRReady(daxi_intf.MRReady), .s_MRReady(ram_bus.MRReady),
        .m_MRRData(daxi_intf.MRRData), .s_MRRData(ram_bus.MRRData),
        .m_MRRResp(daxi_intf.MRRResp), .s_MRRResp(ram_bus.MRRResp),
        .m_MRRLast(daxi_intf.MRRLast), .s_MRRLast(ram_bus.MRRLast),
        .m_MRRValid(daxi_intf.MRRValid), .s_MRRValid(ram_bus.MRRValid)
    );

    // Both caches read the same physical RAM. Data refills win simultaneous
    // requests. The RAM accepts one burst at a time, so latch its owner at AR.
    logic select_i, hold_i, i_read, ram_ar_ready, ram_r_valid, ram_r_last;
    axi_resp_t ram_r_resp;
    logic [FINAL_DATA_WIDTH-1:0] ram_r_data;

    assign select_i = hold_i || !ram_bus.MARValid;
    always_ff @(posedge clk or negedge intf.rst)
        if(!intf.rst) begin
            hold_i <= 1'b0;
            i_read <= 1'b0;
        end
        else begin
            // Keep a stalled instruction address stable if a data request arrives.
            hold_i <= select_i && iaxi_intf.MARValid && !ram_ar_ready;
            if(ram_ar_ready && (ram_bus.MARValid || iaxi_intf.MARValid))
                i_read <= select_i;
        end

    assign iaxi_intf.MARReady = ram_ar_ready && select_i;
    assign ram_bus.MARReady = ram_ar_ready && !select_i;
    assign iaxi_intf.MRRValid = ram_r_valid && i_read;
    assign ram_bus.MRRValid = ram_r_valid && !i_read;
    assign {iaxi_intf.MRRData, iaxi_intf.MRRResp, iaxi_intf.MRRLast} =
           {ram_r_data, ram_r_resp, ram_r_last};
    assign {ram_bus.MRRData, ram_bus.MRRResp, ram_bus.MRRLast} =
           {ram_r_data, ram_r_resp, ram_r_last};
    assign {iaxi_intf.MAWReady, iaxi_intf.MWReady, iaxi_intf.MBValid} = '0;
    assign iaxi_intf.MBResp = AXI_OKAY;

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
        .MARAddr(select_i ? iaxi_intf.MARAddr : ram_bus.MARAddr),
        .MARLen(select_i ? iaxi_intf.MARLen : ram_bus.MARLen),
        .MARSize(select_i ? iaxi_intf.MARSize : ram_bus.MARSize),
        .MARBurst(select_i ? iaxi_intf.MARBurst : ram_bus.MARBurst),
        .MARValid(ram_bus.MARValid || iaxi_intf.MARValid),
        .MARReady(ram_ar_ready),
        .MRReady(i_read ? iaxi_intf.MRReady : ram_bus.MRReady),
        .MRRData(ram_r_data),
        .MRRResp(ram_r_resp),
        .MRRLast(ram_r_last),
        .MRRValid(ram_r_valid)
    );

    always_comb
    begin
        iaxi_intf.rst = intf.rst;
        daxi_intf.rst = intf.rst;
    end

    bind DUT.Fetch fetch_wr Fetch_bind
    (
        .*
    );
    
    bind DUT.Decode decode_wr DecodeBind
    (
        .*
    );
    

    bind DUT.Execute execute_wr ExecuteBind
    (
        .*
    );
    
    bind DUT.Execute.FPU flp_wr FPU_bind
    (
        .*
    );

    bind DUT.Execute.CSR csr_wr CSR_bind
    (
        .*
    );

    bind DUT.Memory memory_wr MemBind
    (
        .*
    );

    bind DUT.WriteBack wb_wr WritebackBind
    (
        .*
    );

    // ISA golden-model lock-step checker (the architectural reference)
    bind DUT commit_checker ISSChecker
    (
        .*,
        .TrapTakenE(Execute.TrapTaken),
        .CsrReadE(Execute.CsrReadE),
        .MepcE(Execute.CSR.Mepc),
        .McauseE(Execute.CSR.Mcause),
        .MtvalE(Execute.CSR.Mtval),
        .SepcE(Execute.CSR.Sepc),
        .ScauseE(Execute.CSR.Scause),
        .StvalE(Execute.CSR.Stval),
        .PrivModeE(Execute.CSR.PrivMode),
        .AtomicStoreM(Memory.AmoM && Memory.CacheWriteEnM && Memory.CacheHitC),
        .AtomicStoreDataM(Memory.StoreSrcM)
    );

    bind DUT.Hazard hazard_wr HazardBind
    (        
        .*
    );
    

    // Timing assertions (Verification/<unit>/<unit>_sva.sv)
    bind fetch_stage   fetch_sva   FetchSva   (.*);
    bind decode_stage  decode_sva  DecodeSva  (.*);
    bind execute_stage execute_sva ExecuteSva (.*);
    bind memory_stage  memory_sva  MemorySva  (.*);
    bind wb_stage      wb_sva      WbSva      (.*);
    bind hazard_unit   hazard_sva  HazardSva  (.*);
    bind risc_fpu fpu_sva #(.WIDTH(WIDTH)) FpuSva (.*);
    bind csr_file csr_sva CsrSva (.*);
    bind cache cache_sva #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .TOTAL_LINES(TOTAL_LINES), .WAY(WAY), .LINE_WORDS(LINE_WORDS)) CacheSva (.*);

    // FENCE.I drains MEM before an instruction can reach EX again.
    a_fence_issue: assert property (@(posedge clk) disable iff ($sampled(intf.rst) !== 1'b1)
        DUT.FenceIStartE |=> DUT.FenceIM && !DUT.ValidD && !DUT.ValidE)
        else uvm_report_error("SVA_FENCE_I", "FENCE.I did not squash younger instructions on issue");
    a_fence_wait: assert property (@(posedge clk) disable iff ($sampled(intf.rst) !== 1'b1)
        DUT.FenceIBusyM |-> DUT.StallW && !DUT.ValidE && !DUT.Fetch.ICache.CPUReadEn)
        else uvm_report_error("SVA_FENCE_I", "Pipeline advanced or fetched during cache maintenance");
    a_fence_invalidate: assert property (@(posedge clk) disable iff ($sampled(intf.rst) !== 1'b1)
        DUT.CPUInvalidateAll |-> DUT.Memory.CPUFlushDone && DUT.FenceIBusyM)
        else uvm_report_error("SVA_FENCE_I", "I-cache invalidated before D-cache write-back completed");
    a_fence_restart: assert property (@(posedge clk) disable iff ($sampled(intf.rst) !== 1'b1)
        DUT.FenceIRestartM |-> DUT.FenceIM && DUT.CPUInvalidateDone && !DUT.StallW ##1
        DUT.PCF == $past(DUT.PCPlus4M) && DUT.ValidW && !DUT.ValidM)
        else uvm_report_error("SVA_FENCE_I", "FENCE.I did not complete and restart fetch at PC+4");
    a_fence_restart_cover: cover property (@(posedge clk) disable iff ($sampled(intf.rst) !== 1'b1)
        DUT.FenceIRestartM ##1 DUT.PCF == $past(DUT.PCPlus4M));

    initial 
    begin
        clk = 0;
        forever 
        begin
            #(CLK_PERIOD/2) clk = !clk;
        end
    end

    // Load 32-bit instructions into XLEN-wide little-endian RAM after its
    // time-zero clear. Compliance images include code and initialized data.
    initial
    begin
        localparam int PER_WORD = FINAL_DATA_WIDTH / INSTR_WIDTH;
        bit [INSTR_WIDTH-1:0] image [2**(FINAL_ADDR_WIDTH-2)];
        int fd;
        #1;
        $readmemb(tb_base_pkg::program_file("binary1.txt"), image);
        foreach (image[i])
            DataMem.mem[i/PER_WORD][INSTR_WIDTH*(i%PER_WORD) +: INSTR_WIDTH] = image[i];
        fd = $fopen(tb_base_pkg::program_file("dmem.hex"), "r");
        if(fd != 0)
        begin
            $fclose(fd);
            $readmemh(tb_base_pkg::program_file("dmem.hex"), DataMem.mem);
        end
    end

    // +UVM_TESTNAME selects the test (risc_test, risc_compliance_test)
    initial
    begin
        uvm_config_db #(virtual risc_interface)::set(null,"","INTF",intf);
        uvm_config_db #(virtual axi_interface #(FINAL_DATA_WIDTH, FINAL_ADDR_WIDTH,
            CACHE_AXI_SIZE))::set(null,"","AXI_INTF",daxi_intf);
        uvm_config_db #(virtual axi_interface #(FINAL_DATA_WIDTH, FINAL_ADDR_WIDTH,
            CACHE_AXI_SIZE))::set(null,"uvm_test_top.FetchEnvironment.predictor","I_AXI",iaxi_intf);
        run_test("risc_test");
    end

endmodule
