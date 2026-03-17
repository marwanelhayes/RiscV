package hazard_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import hazard_item_pkg::*;

    class hazard_scoreboard extends uvm_scoreboard;


        logic LWStall;
        logic FPUStall;
        logic [2:0] ForwardAE;
        logic [2:0] ForwardBE;
        logic StallD;
        logic StallF;
        logic FlushE;
        logic FlushD;
        logic [1:0] ForwardFloatingAE;
        logic [1:0] ForwardFloatingBE;


        int success,fail;

        //Register the class to the factory
        `uvm_component_utils(hazard_scoreboard)

        //Override the constructor function
        function new (string name = "hazard_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        hazard_item sc_item;
        uvm_analysis_imp #(hazard_item , hazard_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ref_model (); 
            LWStall = 1'b0;
            FPUStall = 1'b0;
            ForwardAE = 3'b000;
            ForwardBE = 3'b000;
            StallD = 1'b0;
            StallF = 1'b0;
            FlushE = 1'b0;
            FlushD = 1'b0;
            ForwardFloatingAE = 2'b00;
            ForwardFloatingBE = 2'b00; 

            if (sc_item.SelectorE == MemToReg && ((sc_item.RdE == sc_item.Rs1D) || (sc_item.RdE == sc_item.Rs2D))) 
                LWStall = 1'b1;
            if(sc_item.FPUValidE && sc_item.FPUBusyM)
                FPUStall = 1'b1;
            
            if (sc_item.RegWriteW && (sc_item.RdW != zero) && (sc_item.RdW == sc_item.Rs1E) && (sc_item.MoveOperationE != FPUToReg)) 
            begin
                ForwardAE = 3'b001;
            end
            else if (sc_item.RegWriteM && (sc_item.RdM != zero) && (sc_item.RdM == sc_item.Rs1E) && (sc_item.MoveOperationE != FPUToReg)) 
            begin
                ForwardAE = 3'b010;
            end 
            else if(sc_item.RegWriteW && (sc_item.RdW != zero) && (sc_item.RdW == sc_item.Rs1E) && (sc_item.MoveOperationE == FPUToReg))
            begin
                ForwardAE = 3'b011;
            end
            else if (sc_item.RegWriteM && (sc_item.RdM != zero) && (sc_item.RdM == sc_item.Rs1E) && (sc_item.MoveOperationE == FPUToReg)) 
            begin
                ForwardAE = 3'b100;
            end

            //Forward for target register
            if (sc_item.RegWriteW && (sc_item.RdW != zero) && (sc_item.RdW == sc_item.Rs2E) && (sc_item.MoveOperationE != FPUToReg)) 
            begin
                ForwardBE = 3'b001;
            end
            else if (sc_item.RegWriteM && (sc_item.RdM != zero) && (sc_item.RdM == sc_item.Rs2E) && (sc_item.MoveOperationE != FPUToReg)) 
            begin
                ForwardBE = 3'b010;
            end 
            else if(sc_item.RegWriteW && (sc_item.RdW != zero) && (sc_item.RdW == sc_item.Rs2E) && (sc_item.MoveOperationE == FPUToReg))
            begin
                ForwardBE = 3'b011;
            end
            else if(sc_item.RegWriteM && (sc_item.RdM != zero) && (sc_item.RdM == sc_item.Rs2E) && (sc_item.MoveOperationE == FPUToReg))
            begin
                ForwardBE = 3'b100;
            end

            if(sc_item.FPURegWriteW && (sc_item.RdFW != f0) && (sc_item.RdFW == sc_item.Rs1FE))
            begin
                ForwardFloatingAE = 2'b01;
            end
            else if(sc_item.FPURegWriteM && (sc_item.RdFM != f0) && (sc_item.RdFM == sc_item.Rs1FE))
            begin
                ForwardFloatingAE = 2'b10;
            end

            if(sc_item.FPURegWriteW && (sc_item.RdFW != f0) && (sc_item.RdFW == sc_item.Rs2FE))
            begin
                ForwardFloatingBE = 2'b01;
            end
            else if(sc_item.FPURegWriteM && (sc_item.RdFM != f0) && (sc_item.RdFM == sc_item.Rs2FE))
            begin
                ForwardFloatingBE = 2'b10;
            end
                    
            StallD = LWStall        || FPUStall;
            StallF = LWStall        || FPUStall;
            FlushE = LWStall        || sc_item.PCSrcE || sc_item.TrapIsSet;
            FlushD = sc_item.PCSrcE || sc_item.TrapIsSet;

        endfunction:ref_model

        function void check_output ();
            ref_model();
            if(ForwardAE != sc_item.ForwardAE || ForwardBE != sc_item.ForwardBE || 
               StallD != sc_item.StallD || StallF != sc_item.StallF || FlushE != sc_item.FlushE || FlushD != sc_item.FlushD || ForwardFloatingAE != sc_item.ForwardFloatingAE || ForwardFloatingBE != sc_item.ForwardFloatingBE)
            begin
                $display("//////////////////////Error occured in the Hazard scoreboard//////////////////////");
                `uvm_info("SCB", sc_item.convert2str, UVM_MEDIUM)
                if(ForwardAE != sc_item.ForwardAE)
                begin
                    `uvm_info("SCB", $sformatf("Expected ForwardAE = %0b, Got ForwardAE = %0b", sc_item.ForwardAE, ForwardAE), UVM_MEDIUM)
                    fail++;
                end
                if(ForwardBE != sc_item.ForwardBE)
                begin
                    `uvm_info("SCB", $sformatf("Expected ForwardBE = %0b, Got ForwardBE = %0b", sc_item.ForwardBE, ForwardBE), UVM_MEDIUM)
                    fail++;
                end
                if(StallD != sc_item.StallD)
                begin
                    `uvm_info("SCB", $sformatf("Expected StallD = %0b, Got StallD = %0b", sc_item.StallD, StallD), UVM_MEDIUM)
                    fail++;
                end
                if(StallF != sc_item.StallF)
                begin
                    `uvm_info("SCB", $sformatf("Expected StallF = %0b, Got StallF = %0b", sc_item.StallF, StallF), UVM_MEDIUM)
                    fail++;
                end
                if(FlushE != sc_item.FlushE)
                begin
                    `uvm_info("SCB", $sformatf("Expected FlushE = %0b, Got FlushE = %0b", sc_item.FlushE, FlushE), UVM_MEDIUM)
                    fail++;
                end
                if(FlushD != sc_item.FlushD)
                begin
                    `uvm_info("SCB", $sformatf("Expected FlushD = %0b, Got FlushD = %0b", sc_item.FlushD, FlushD), UVM_MEDIUM)
                    fail++;
                end
                if(ForwardFloatingAE != sc_item.ForwardFloatingAE)
                begin
                    `uvm_info("SCB", $sformatf("Expected ForwardFloatingAE = %0b, Got ForwardFloatingAE = %0b", sc_item.ForwardFloatingAE, ForwardFloatingAE), UVM_MEDIUM)
                    fail++;
                end
                if(ForwardFloatingBE != sc_item.ForwardFloatingBE)
                begin
                    `uvm_info("SCB", $sformatf("Expected ForwardFloatingBE = %0b, Got ForwardFloatingBE = %0b", sc_item.ForwardFloatingBE, ForwardFloatingBE), UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (hazard_item item);
            sc_item = item;
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","sc_itemoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Scoreboard Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Scoreboard Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:hazard_scoreboard

endpackage:hazard_scoreboard_pkg
