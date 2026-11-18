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


    riscv_processor #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH)) 
    DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .ExternalInterrupt(intf.ExternalInterrupt),
        .TimerInterrupt(intf.TimerInterrupt),
        .SoftwareInterrupt(intf.SoftwareInterrupt),
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

    // ── Memory slaves on the core's I/D AXI master ports (as in fetch_top /
    //    mem_top); the core itself holds only the L1 caches.
    // Published to the TB before any initial block runs (variable initializer)
    bit program_dir_set = tb_base_pkg::set_program_dir(PROGRAM_DIR);

    risc_instruction_memory #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH),
                              .AXI_SIZE(CACHE_AXI_SIZE), .INIT_FILE({PROGRAM_DIR, "/binary1.txt"})) InstrMem
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .MAWAddr(iaxi_intf.MAWAddr),
        .MAWLen(iaxi_intf.MAWLen),
        .MAWSize(iaxi_intf.MAWSize),
        .MAWBurst(iaxi_intf.MAWBurst),
        .MAWValid(iaxi_intf.MAWValid),
        .MAWReady(iaxi_intf.MAWReady),
        .MWData(iaxi_intf.MWData),
        .MWStrb(iaxi_intf.MWStrb),
        .MWLast(iaxi_intf.MWLast),
        .MWValid(iaxi_intf.MWValid),
        .MWReady(iaxi_intf.MWReady),
        .MBReady(iaxi_intf.MBReady),
        .MBResp(iaxi_intf.MBResp),
        .MBValid(iaxi_intf.MBValid),
        .MARAddr(iaxi_intf.MARAddr),
        .MARLen(iaxi_intf.MARLen),
        .MARSize(iaxi_intf.MARSize),
        .MARBurst(iaxi_intf.MARBurst),
        .MARValid(iaxi_intf.MARValid),
        .MARReady(iaxi_intf.MARReady),
        .MRReady(iaxi_intf.MRReady),
        .MRRData(iaxi_intf.MRRData),
        .MRRResp(iaxi_intf.MRRResp),
        .MRRLast(iaxi_intf.MRRLast),
        .MRRValid(iaxi_intf.MRRValid)
    );

    risc_data_memory #(FINAL_DATA_WIDTH,FINAL_ADDR_WIDTH,CACHE_AXI_SIZE) DataMem
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .MAWAddr(daxi_intf.MAWAddr),
        .MAWLen(daxi_intf.MAWLen),
        .MAWSize(daxi_intf.MAWSize),
        .MAWBurst(daxi_intf.MAWBurst),
        .MAWValid(daxi_intf.MAWValid),
        .MAWReady(daxi_intf.MAWReady),
        .MWData(daxi_intf.MWData),
        .MWStrb(daxi_intf.MWStrb),
        .MWLast(daxi_intf.MWLast),
        .MWValid(daxi_intf.MWValid),
        .MWReady(daxi_intf.MWReady),
        .MBReady(daxi_intf.MBReady),
        .MBResp(daxi_intf.MBResp),
        .MBValid(daxi_intf.MBValid),
        .MARAddr(daxi_intf.MARAddr),
        .MARLen(daxi_intf.MARLen),
        .MARSize(daxi_intf.MARSize),
        .MARBurst(daxi_intf.MARBurst),
        .MARValid(daxi_intf.MARValid),
        .MARReady(daxi_intf.MARReady),
        .MRReady(daxi_intf.MRReady),
        .MRRData(daxi_intf.MRRData),
        .MRRResp(daxi_intf.MRRResp),
        .MRRLast(daxi_intf.MRRLast),
        .MRRValid(daxi_intf.MRRValid)
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

    initial 
    begin
        clk = 0;
        forever 
        begin
            #(CLK_PERIOD/2) clk = !clk;
        end
    end

    // Compliance programs also have a data image (dmem.hex). It is loaded at
    // #1, after the data memory clears itself at time 0 and while reset is held.
    initial
    begin
        int fd;
        #1;
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
        run_test("risc_test");
    end

endmodule
