module risc_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "parameters_risc.svh"

    import risc_test_pkg::*;

    bit clk;


    risc_interface #(`CLK,`DATA_WIDTH,`ADDR_WIDTH) intf (clk);

    localparam CLK_PERIOD = `CLK;


    riscv_processor #(.DATA_WIDTH(`DATA_WIDTH), .ADDR_WIDTH(`ADDR_WIDTH)) 
    DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst)
    );

    bind DUT.Fetch fetch_wr #(.CLK_PERIOD(`CLK),.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) 
    Fetch_bind
    (
        .*
    );
    
    bind DUT.Decode decode_wr #(.CLK_PERIOD(`CLK),.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) 
    DecodeBind
    (
        .*
    );
    

    bind DUT.Execute execute_wr #(.CLK_PERIOD(`CLK),.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) 
    ExecuteBind
    (
        .*
    );
    
    bind DUT.Memory memory_wr #(.CLK_PERIOD(`CLK),.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) 
    MemBind
    (
        .*
    );

    bind DUT.WriteBack wb_wr #(.CLK_PERIOD(`CLK),.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) 
    WritebackBind
    (
        .*
    );

    bind DUT.Hazard hazard_wr #(.CLK_PERIOD(`CLK),.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH)) 
    HazardBind
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
        uvm_config_db #(virtual risc_interface #(.DATA_WIDTH(`DATA_WIDTH),.ADDR_WIDTH(`ADDR_WIDTH),.CLK_PERIOD(`CLK)))::set(null,"","INTF",intf);
        run_test();
    end

endmodule