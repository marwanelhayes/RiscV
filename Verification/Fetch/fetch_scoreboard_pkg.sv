package fetch_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import fetch_item_pkg::*;

    class fetch_scoreboard extends uvm_scoreboard;


        
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4D;
        logic [FINAL_DATA_WIDTH-1:0] InstructionD;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4F;

        localparam int DEPTH = (2**(FINAL_ADDR_WIDTH-2));

        logic signed [FINAL_DATA_WIDTH-1:0] memory [DEPTH-1:0];


        int success,fail;

        //Register the class to the factory
        `uvm_component_utils(fetch_scoreboard)

        //Override the constructor function
        function new (string name = "fetch_scoreboard", uvm_component parent = null);
            super.new(name,parent);
            $readmemb("C:/Ain_shams/RiscV/Python/binary1.txt",memory);
        endfunction:new

        fetch_item sc_item;
        uvm_analysis_imp #(fetch_item , fetch_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ref_model ();
            PCPlus4F = sc_item.PCF + 4;
            if(!sc_item.rst)
            begin
                PCPlus4D = 0;
                InstructionD = 32'h00_00_00_33;
            end
            else
            begin
                if(sc_item.FlushD)
                begin
                    InstructionD = 32'h00_00_00_33;
                    PCPlus4D = 0;
                end
                else if(!sc_item.StallD)
                begin
                    InstructionD = memory[sc_item.PCF[FINAL_ADDR_WIDTH-1:2]];
                    PCPlus4D = sc_item.PCF + 4;
                end
            end
        endfunction:ref_model

        function void check_output ();
            ref_model();
            if(sc_item.PCPlus4D != PCPlus4D || sc_item.InstructionD != InstructionD || sc_item.PCPlus4F != PCPlus4F)
            begin
                $display("//////////////////////Error occured in the Fetch scoreboard//////////////////////");
                `uvm_info("SCB",sc_item.convert2str,UVM_MEDIUM)
                if(sc_item.PCPlus4D != PCPlus4D)
                begin
                    `uvm_info("SCB",$sformatf("Actual output PCPlus4D = %0h -- PCPlus4D = %0h",sc_item.PCPlus4D,PCPlus4D),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.InstructionD != InstructionD)
                begin
                    `uvm_info("SCB",$sformatf("Actual output InstructionD = %0h -- InstructionD = %0h",sc_item.InstructionD,InstructionD),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.PCPlus4F != PCPlus4F)
                begin
                    `uvm_info("SCB",$sformatf("Actual output PCPlus4F = %0h -- PCPlus4F = %0h",sc_item.PCPlus4F,PCPlus4F),UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (fetch_item item);
            sc_item = item;
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","FETCH Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:fetch_scoreboard

endpackage:fetch_scoreboard_pkg
