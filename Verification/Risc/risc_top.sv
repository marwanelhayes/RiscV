// =============================================================================
// risc_top.sv
// -----------------------------------------------------------------------------
// RISC-V processor top-level testbench module for UVM verification.
// =============================================================================
module risc_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import shared_pkg::*;
    import risc_test_pkg::*;

    bit clk;


    risc_interface intf (clk);


    riscv_processor #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH)) 
    DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .ExternalInterrupt(intf.ExternalInterrupt),
        .TimerInterrupt(intf.TimerInterrupt),
        .SoftwareInterrupt(intf.SoftwareInterrupt)
    );

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
    
    bind DUT.Memory memory_wr MemBind
    (
        .*
    );

    bind DUT.WriteBack wb_wr WritebackBind
    (
        .*
    );

    bind DUT.Hazard hazard_wr HazardBind
    (        
        .*
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

        test_name = "risc_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "risc_test")
                test_name = "risc_test";
        end

        uvm_config_db #(virtual risc_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
