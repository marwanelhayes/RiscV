package writeback_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import writeback_item_pkg::*;

    class writeback_scoreboard extends uvm_scoreboard;


        logic [FINAL_DATA_WIDTH-1:0] ResultW;
        logic [FINAL_ADDR_WIDTH-1:0] PCF;


        int success,fail;

        //Register the class to the factory
        `uvm_component_utils(writeback_scoreboard)

        //Override the constructor function
        function new (string name = "writeback_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        writeback_item sc_item;
        uvm_analysis_imp #(writeback_item , writeback_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ref_model ();
            
            if(!sc_item.rst)
            begin
                PCF = 'b0;
            end
            else if(sc_item.TrapIsSet)
            begin
                PCF = sc_item.CsrOutPC;
            end
            else if(!sc_item.StallF)
            begin
                if(sc_item.PCSrcE)
                begin
                    PCF = sc_item.PCBranchE;
                end
                else
                begin
                    PCF = sc_item.PCPlus4F;
                end
            end

            case (sc_item.SelectorW)
                ALUToReg: ResultW = sc_item.ALUOutW; // ALU result
                MemToReg: ResultW = sc_item.ReadDataW; // Memory read data
                CSRToReg: ResultW = sc_item.CsrOutW; // CSR read data
                PCToReg : ResultW = sc_item.PCPlus4W; // PC + 4
            endcase
        endfunction:ref_model

        function void check_output ();
            ref_model();
            if(sc_item.ResultW != ResultW || sc_item.PCF != PCF)
            begin
                `uvm_info("SCB",sc_item.convert2str,UVM_HIGH)
                if(sc_item.ResultW != ResultW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output ResultW = %0h -- ResultW = %0h",sc_item.ResultW,ResultW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.PCF != PCF)
                begin
                    `uvm_info("SCB",$sformatf("Actual output PCF = %0h -- PCF = %0h",sc_item.PCF,PCF),UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (writeback_item item);
            sc_item = item;
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","sc_itemoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Scoreboard Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Scoreboard Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:writeback_scoreboard

endpackage:writeback_scoreboard_pkg
