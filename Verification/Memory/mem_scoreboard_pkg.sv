package mem_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import mem_item_pkg::*;

    class mem_scoreboard extends uvm_scoreboard;


        
        logic signed [FINAL_DATA_WIDTH-1:0] ReadDataW;
        gpr_t RdW;
        logic RegWriteW;
        selector_t SelectorW;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4W;
        logic [FINAL_DATA_WIDTH-1:0] CsrOutW;
        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutW;
        fpr_t RdFW;
        logic OverflowW;
        logic UnderflowW;
        logic NaNW;
        logic InfW;    
        logic ZeroW;
        logic InvalidDivW;
        logic [FINAL_DATA_WIDTH-1:0] FPUOutW;
        move_operation_t MoveOperationW;
        logic FPURegWriteW;

        localparam int DEPTH = (2**(FINAL_ADDR_WIDTH-2));

        logic signed [FINAL_DATA_WIDTH-1:0] memory [DEPTH-1:0];


        int success,fail;

        //Register the class to the factory
        `uvm_component_utils(mem_scoreboard)

        //Override the constructor function
        function new (string name = "mem_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        mem_item sc_item;
        uvm_analysis_imp #(mem_item , mem_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ref_model ();
            ReadDataW = 'b0;
            if(!sc_item.rst)
            begin
                RdW = zero;
                RegWriteW = 'b0;
                SelectorW = ALUToReg;
                ALUOutW = 'b0;
                ReadDataW = 'b0;
                PCPlus4W = 'b0;
                CsrOutW = 'b0;
                RdFW = f0;
                OverflowW = 'b0;
                UnderflowW = 'b0;
                NaNW = 'b0;
                InfW = 'b0;
                ZeroW = 'b0;
                InvalidDivW = 'b0;
                FPUOutW = 'b0;
                MoveOperationW = FPUToFPU;
                FPURegWriteW = 'b0;
                foreach(memory[i])
                    memory[i] = 'b0;
            end
            else
            begin
                if(sc_item.MemWriteM)
                begin
                    case(load_store_t'(sc_item.funct3M))
                        W: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]] = sc_item.WriteDataM;
                        HW:  case(sc_item.ALUOutM[1])
                            1'b1: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH/2] = sc_item.WriteDataM[FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH/2];
                            1'b0: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH/2-1:'b0] = sc_item.WriteDataM[FINAL_DATA_WIDTH/2-1:0];
                        endcase
                        B:  case(sc_item.ALUOutM[1:0])
                            2'b11: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))] = sc_item.WriteDataM[FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))];
                            2'b10: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)] = sc_item.WriteDataM[(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)];
                            2'b01: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)] = sc_item.WriteDataM[(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)];
                            2'b00: memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1:'b0] = sc_item.WriteDataM[(FINAL_DATA_WIDTH/4)-1:0];
                        endcase
                    endcase
                end
                case(load_store_t'(sc_item.funct3M))
                    W: ReadDataW = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]];
                    HW:  case(sc_item.ALUOutM[1])
                            1'b1:   begin
                                        ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)];
                                        ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)] = {FINAL_DATA_WIDTH/2{memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH)-1]}};
                                    end
                            1'b0:   begin
                                        ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:'b0];
                                        ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)] = {FINAL_DATA_WIDTH/2{memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1]}};
                                    end
                        endcase
                    HWU:  case(sc_item.ALUOutM[1]) //For unsinged case the most significant bits remain zero
                            1'b1:   begin
                                        ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/2)];
                                    end
                            1'b0:   begin
                                        ReadDataW[(FINAL_DATA_WIDTH/2)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:'b0];
                                    end
                        endcase
                    B:  case(sc_item.ALUOutM[1:0])
                            2'b11:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))];
                                        ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH)-1]}};
                                    end
                            2'b10:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)];
                                        ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*FINAL_DATA_WIDTH/4)-1]}};
                                    end
                            2'b01:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)];
                                        ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1]}};
                                    end
                            2'b00:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1:'b0];
                                        ReadDataW[FINAL_DATA_WIDTH-1:(FINAL_DATA_WIDTH/4)] = {3*(FINAL_DATA_WIDTH/4){memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1]}};
                                    end
                        endcase
                    BU:  case(sc_item.ALUOutM[1:0]) //For unsinged the most significant bits remain zero
                            2'b11:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][FINAL_DATA_WIDTH-1:(3*(FINAL_DATA_WIDTH/4))];
                                    end
                            2'b10:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(3*(FINAL_DATA_WIDTH/4))-1:(FINAL_DATA_WIDTH/2)];
                                    end 
                            2'b01:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/2)-1:(FINAL_DATA_WIDTH/4)];
                                    end
                            2'b00:  begin
                                        ReadDataW[(FINAL_DATA_WIDTH/4)-1:'b0] = memory[sc_item.ALUOutM[FINAL_ADDR_WIDTH-1:2]][(FINAL_DATA_WIDTH/4)-1:'b0];
                                    end
                        endcase
                endcase
                RdW = sc_item.RdM;
                RegWriteW = sc_item.RegWriteM;
                SelectorW = sc_item.SelectorM;
                ALUOutW = sc_item.ALUOutM;
                CsrOutW = sc_item.CsrOutM;
                PCPlus4W = sc_item.PCPlus4M;
                RdFW = sc_item.RdFM;
                OverflowW = sc_item.OverflowM;
                UnderflowW = sc_item.UnderflowM;
                NaNW = sc_item.NaNM;
                InfW = sc_item.InfM;
                ZeroW = sc_item.ZeroM;
                InvalidDivW = sc_item.InvalidDivM;
                FPUOutW = sc_item.FPUOutM;
                MoveOperationW = sc_item.MoveOperationM;
                FPURegWriteW = sc_item.FPURegWriteM;
            end
        endfunction:ref_model

        function void check_output ();
            ref_model();
            if(
                sc_item.ReadDataW != ReadDataW || 
                sc_item.RdW != RdW || 
                sc_item.RegWriteW != RegWriteW || 
                sc_item.SelectorW != SelectorW || 
                sc_item.CsrOutW != CsrOutW || 
                sc_item.PCPlus4W != PCPlus4W || 
                sc_item.ALUOutW != ALUOutW || 
                sc_item.RdFW != RdFW || 
                sc_item.OverflowW != OverflowW || 
                sc_item.UnderflowW != UnderflowW || 
                sc_item.NaNW != NaNW || 
                sc_item.InfW != InfW || 
                sc_item.ZeroW != ZeroW || 
                sc_item.InvalidDivW != InvalidDivW || 
                sc_item.FPUOutW != FPUOutW || 
                sc_item.MoveOperationW != MoveOperationW || 
                sc_item.FPURegWriteW != FPURegWriteW
                )
            begin
                $display("//////////////////////Error occured in the Memory scoreboard//////////////////////");
                `uvm_info("SCB",sc_item.convert2str,UVM_MEDIUM)
                if(sc_item.ReadDataW != ReadDataW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output ReadDataW = %0h -- ReadDataW = %0h",sc_item.ReadDataW,ReadDataW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RdW != RdW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RdW = %0h -- RdW = %0h",sc_item.RdW,RdW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RegWriteW != RegWriteW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RegWriteW = %b -- RegWriteW = %b",sc_item.RegWriteW,RegWriteW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.SelectorW != SelectorW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output SelectorW = %s -- SelectorW = %s",sc_item.SelectorW.name(),SelectorW.name()),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.CsrOutW != CsrOutW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output CsrOutW = %0h -- CsrOutW = %0h",sc_item.CsrOutW,CsrOutW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.PCPlus4W != PCPlus4W)
                begin
                    `uvm_info("SCB",$sformatf("Actual output PCPlus4W = %0h -- PCPlus4W = %0h",sc_item.PCPlus4W,PCPlus4W),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.ALUOutW != ALUOutW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output ALUOutW = %0h -- ALUOutW = %0h",sc_item.ALUOutW,ALUOutW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RdFW != RdFW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RdFW = %s -- RdFW = %s",sc_item.RdFW.name(),RdFW.name()),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.OverflowW != OverflowW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output OverflowW = %b -- OverflowW = %b",sc_item.OverflowW,OverflowW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.UnderflowW != UnderflowW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output UnderflowW = %b -- UnderflowW = %b",sc_item.UnderflowW,UnderflowW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.NaNW != NaNW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output NaNW = %b -- NaNW = %b",sc_item.NaNW,NaNW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.InfW != InfW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output InfW = %b -- InfW = %b",sc_item.InfW,InfW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.ZeroW != ZeroW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output ZeroW = %b -- ZeroW = %b",sc_item.ZeroW,ZeroW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.InvalidDivW != InvalidDivW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output InvalidDivW = %b -- InvalidDivW = %b",sc_item.InvalidDivW,InvalidDivW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.FPUOutW != FPUOutW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output FPUOutW = %0h -- FPUOutW = %0h",sc_item.FPUOutW,FPUOutW),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.MoveOperationW != MoveOperationW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output MoveOperationW = %s -- MoveOperationW = %s",sc_item.MoveOperationW.name(),MoveOperationW.name()),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.FPURegWriteW != FPURegWriteW)
                begin
                    `uvm_info("SCB",$sformatf("Actual output FPURegWriteW = %b -- FPURegWriteW = %b",sc_item.FPURegWriteW,FPURegWriteW),UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (mem_item item);
            sc_item = item;
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","MEMORY Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:mem_scoreboard

endpackage:mem_scoreboard_pkg
