package execute_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import execute_item_pkg::*;

    class execute_scoreboard extends uvm_scoreboard;

        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM;
        logic signed [FINAL_DATA_WIDTH-1:0] WriteDataM;
        gpr_t RdM;
        logic PCSrcE;
        logic RegWriteM;
        logic [FINAL_ADDR_WIDTH-1:0] PCPlus4M;
        selector_t SelectorM;
        logic [2:0] funct3M;
        logic MemWriteM;
        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutE;
        logic signed [2*FINAL_DATA_WIDTH-1:0] MulOutput;
        logic signed [FINAL_DATA_WIDTH-1:0] DivOutput;
        logic signed [FINAL_DATA_WIDTH-1:0] RemOutput;


        traps_t Traps;

        logic signed [FINAL_DATA_WIDTH-1:0] IntermediateB , SrcA,SrcB;
        logic [FINAL_DATA_WIDTH-1:0] SrcBU;

        logic branch_true;
        logic signed [FINAL_DATA_WIDTH-1:0] ALUOutM_past;
        int success,fail;
        logic [FINAL_FLP_WIDTH-1:0] FPUOutM_past;

        localparam int LOG_WIDTH = $clog2(FINAL_DATA_WIDTH);

        //Register the class to the factory
        `uvm_component_utils(execute_scoreboard)

        //Override the constructor function
        function new (string name = "execute_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        execute_item sc_item;
        uvm_analysis_imp #(execute_item , execute_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ref_model ();
            case(sc_item.ALUControlE)
                ADD : ALUOutE = SrcA + SrcB;
                SUB : ALUOutE = SrcA - SrcB;
                AND : ALUOutE = SrcA & SrcB;
                OR : ALUOutE = SrcA | SrcB;
                XOR : ALUOutE = SrcA ^ SrcB;
                SLT : ALUOutE = $signed(SrcA) < $signed(SrcB);
                SLTU : ALUOutE = $unsigned(SrcA) < $unsigned(SrcB);
                SLL : ALUOutE = SrcA << SrcB[LOG_WIDTH-1:0];
                SRL : ALUOutE = SrcA >> SrcB[LOG_WIDTH-1:0];
                SRA : ALUOutE = $signed(SrcA) >>> SrcB[LOG_WIDTH-1:0];
                MUL : ALUOutE = MulOutput[FINAL_DATA_WIDTH-1:0];
                MULH : ALUOutE = MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                MULHSU : ALUOutE = MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                MULHU : ALUOutE = $unsigned(MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                DIV : ALUOutE = DivOutput;
                REM : ALUOutE = RemOutput;
                DIVU : ALUOutE = DivOutput;
                REMU : ALUOutE = RemOutput;
                default : ALUOutE = 'b0;
            endcase

            if(!sc_item.rst)
            begin
                ALUOutM = 'b0;
                WriteDataM = 'b0;
                RdM = zero;
                PCSrcE = 'b0;
                RegWriteM = 'b0;
                funct3M = 'b0;
                MemWriteM = 'b0;
                branch_true = 1'b0;
                ALUOutM_past = 'b0;
                PCPlus4M = 'b0;
                SelectorM = ALUToReg;
                FPUOutM_past = 'b0;
            end
            else
            begin:NotReset
                RdM = sc_item.RdE;
                RegWriteM = sc_item.RegWriteE;
                funct3M = sc_item.funct3E;
                MemWriteM = sc_item.MemWriteE;
                branch_true = 1'b0;
                PCSrcE = 'b0;
                PCPlus4M = sc_item.PCPlus4E;
                SelectorM = sc_item.SelectorE;
                
                case(sc_item.ForwardAE)
                    3'b000 : SrcA = sc_item.RD1E;
                    3'b001 : SrcA = sc_item.ResultW;
                    3'b010 : SrcA = ALUOutM_past;
                    3'b011 : SrcA = sc_item.FPUOutW;
                    3'b100 : SrcA = FPUOutM_past;
                    default : SrcA = 'b0;
                endcase

                case(sc_item.ForwardBE)
                    3'b000 : IntermediateB = sc_item.RD2E;
                    3'b001 : IntermediateB = sc_item.ResultW;
                    3'b010 : IntermediateB = ALUOutM_past;
                    3'b011 : IntermediateB = sc_item.FPUOutW;
                    3'b100 : IntermediateB = FPUOutM_past;
                    default : IntermediateB = 'b0;
                endcase


                WriteDataM = IntermediateB;

                case(sc_item.ALUSrcE)
                    1'b0 : SrcB = IntermediateB;
                    1'b1 : SrcB = sc_item.SignImmE;
                endcase

                SrcBU = SrcB;
                case(sc_item.ALUControlE)
                    MUL : MulOutput = $signed(SrcA) * $signed(SrcB);
                    MULH : MulOutput = $signed(SrcA) * $signed(SrcB);
                    MULHSU : MulOutput = {{FINAL_DATA_WIDTH{SrcA[FINAL_DATA_WIDTH-1]}},SrcA} * {{FINAL_DATA_WIDTH{1'b0}},SrcB};
                    MULHU : MulOutput = $unsigned(SrcA) * $unsigned(SrcB);
                    DIV : 
                    begin
                        if(SrcB == 0)
                            DivOutput = -1;
                        else if((SrcA == -2**(FINAL_DATA_WIDTH-1)) && (SrcB == -1))
                            DivOutput = SrcA;
                        else
                            DivOutput = ($signed(SrcA) / $signed(SrcB));
                    end
                    DIVU : 
                    begin
                        if(SrcB == 0)
                            DivOutput = -1;
                        else
                            DivOutput = ($unsigned(SrcA) / $unsigned(SrcB));
                    end
                    REM : 
                    begin
                        if(SrcB == 0)
                            RemOutput = SrcA;
                        else if((SrcA == -2**(FINAL_DATA_WIDTH-1)) && (SrcB == -1))
                            RemOutput = 0;
                        else
                            RemOutput = $signed(SrcA) % $signed(SrcB);
                    end
                    REMU : 
                    begin
                        if(SrcB == 0)
                            RemOutput = SrcA;
                        else
                            RemOutput = $unsigned(SrcA) % $unsigned(SrcB);
                    end
                endcase

                case(sc_item.ALUControlE)
                    ADD : ALUOutM = SrcA + SrcB;
                    SUB : ALUOutM = SrcA - SrcB;
                    AND : ALUOutM = SrcA & SrcB;
                    OR : ALUOutM = SrcA | SrcB;
                    XOR : ALUOutM = SrcA ^ SrcB;
                    SLT : ALUOutM = $signed(SrcA) < $signed(SrcB);
                    SLTU : ALUOutM = $unsigned(SrcA) < $unsigned(SrcB);
                    SLL : ALUOutM = $unsigned(SrcA) << $unsigned(SrcB[LOG_WIDTH-1:0]);
                    SRL : ALUOutM = $unsigned(SrcA) >> $unsigned(SrcB[LOG_WIDTH-1:0]);
                    SRA : ALUOutM = $signed(SrcA) >>> $unsigned(SrcB[LOG_WIDTH-1:0]);
                    MUL : ALUOutM = MulOutput[FINAL_DATA_WIDTH-1:0];
                    MULH : ALUOutM = MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH];
                    MULHSU : ALUOutM = $signed(MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                    MULHU : ALUOutM = $unsigned(MulOutput[2*FINAL_DATA_WIDTH-1:FINAL_DATA_WIDTH]);
                    DIV : ALUOutM = DivOutput;
                    REM : ALUOutM = RemOutput;
                    DIVU : ALUOutM = $unsigned(DivOutput);
                    REMU : ALUOutM = RemOutput;
                endcase

                case(branch_t'(sc_item.funct3E))
                    BEQ : begin
                                if(SrcA == SrcB)
                                    branch_true = sc_item.BranchE;
                            end
                    BNE : begin
                                if(SrcA != SrcB)
                                    branch_true = sc_item.BranchE;
                            end
                    BLT : begin
                                if($signed(SrcA) < $signed(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BGE : begin
                                if($signed(SrcA) >= $signed(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BLTU : begin
                                if($unsigned(SrcA) < $unsigned(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                    BGEU : begin
                                if($unsigned(SrcA) >= $unsigned(SrcB))
                                    branch_true = sc_item.BranchE;
                            end
                endcase

                PCSrcE = (sc_item.BranchE & branch_true) || sc_item.JumpE;
                ALUOutM_past = sc_item.ALUOutM;
                FPUOutM_past = sc_item.FPUOutM;
                                
                check_output();

            end:NotReset
        endfunction:ref_model

        function void check_output ();
            if (
                ALUOutM[FINAL_DATA_WIDTH-1:0] != sc_item.ALUOutM || 
                WriteDataM != sc_item.WriteDataM || 
                RdM != sc_item.RdM || 
                PCSrcE != sc_item.PCSrcE ||
                RegWriteM != sc_item.RegWriteM || 
                funct3M != sc_item.funct3M || 
                MemWriteM != sc_item.MemWriteM ||
                PCPlus4M != sc_item.PCPlus4M ||
                SelectorM != sc_item.SelectorM
                ) 
            begin
                $display("///////////////////////Error occured in the Execute scoreboard///////////////////////");
                `uvm_info("SCB",{sc_item.convert2str,$sformatf(" and the past ALUOutM = %0d",ALUOutM_past)},UVM_HIGH)
                if (ALUOutM[FINAL_DATA_WIDTH-1:0] != sc_item.ALUOutM) begin
                    `uvm_info("SCB", $sformatf("Actual output ALUOutM = %0d -- ALUOutM = %0d , SrcA = %0d , SrcB = %0d", sc_item.ALUOutM, ALUOutM[FINAL_DATA_WIDTH-1:0], SrcA, SrcB), UVM_MEDIUM)
                    $display("SrcA = %0d , SrcB = %0d , MultiplyOut = %0d Operation %s",SrcA,SrcB,MulOutput,sc_item.ALUControlE.name());
                    fail++;
                end
                if (WriteDataM != sc_item.WriteDataM) begin
                    `uvm_info("SCB", $sformatf("Actual output WriteDataM = %0h -- WriteDataM = %0h", sc_item.WriteDataM, WriteDataM), UVM_MEDIUM)
                    fail++;
                end
                if (RdM != sc_item.RdM) begin
                    `uvm_info("SCB", $sformatf("Actual output RdM = %s -- RdM = %s", sc_item.RdM.name, RdM.name), UVM_MEDIUM)
                    fail++;
                end
                if (PCSrcE != sc_item.PCSrcE) begin
                    `uvm_info("SCB", $sformatf("Actual output PCSrcE = %0h -- PCSrcE = %0h", sc_item.PCSrcE, PCSrcE), UVM_MEDIUM)
                    fail++;
                end
                if (RegWriteM != sc_item.RegWriteM) begin
                    `uvm_info("SCB", $sformatf("Actual output RegWriteM = %0h -- RegWriteM = %0h", sc_item.RegWriteM, RegWriteM), UVM_MEDIUM)
                    fail++;
                end
                if (funct3M != sc_item.funct3M) begin
                    `uvm_info("SCB", $sformatf("Actual output funct3M = %0h -- funct3M = %0h", sc_item.funct3M, funct3M), UVM_MEDIUM)
                    fail++;
                end
                if (MemWriteM != sc_item.MemWriteM) begin
                    `uvm_info("SCB", $sformatf("Actual output MemWriteM = %0h -- MemWriteM = %0h", sc_item.MemWriteM, MemWriteM), UVM_MEDIUM)
                    fail++;
                end
                if (PCPlus4M != sc_item.PCPlus4M) begin
                    `uvm_info("SCB", $sformatf("Actual output PCPlus4M = %0h -- PCPlus4M = %0h", sc_item.PCPlus4M, PCPlus4M), UVM_MEDIUM)
                    fail++;
                end
                if (SelectorM != sc_item.SelectorM) begin
                    `uvm_info("SCB", $sformatf("Actual output SelectorM = %0h -- SelectorM = %0h", sc_item.SelectorM, SelectorM), UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (execute_item item);
            sc_item = item;
            ref_model();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","EXECUTE Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction
            

    endclass:execute_scoreboard

endpackage:execute_scoreboard_pkg
