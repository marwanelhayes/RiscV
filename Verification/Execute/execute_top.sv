// =============================================================================
// execute_top.sv
// -----------------------------------------------------------------------------
// Execute stage top-level testbench module for UVM verification.
// =============================================================================
module execute_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uvm_pkg::uvm_cmdline_processor;
    import execute_test_pkg::*;
    import shared_pkg::*;

    bit clk;

    execute_interface intf (clk);

    execute_stage #(.DATA_WIDTH(FINAL_DATA_WIDTH), .ADDR_WIDTH(FINAL_ADDR_WIDTH)) DUT 
    (
        .clk(intf.clk),
        .rst(intf.rst),
        .ValidE(intf.ValidE),
        .RD1E(intf.RD1E),
        .RD2E(intf.RD2E),
        .SignImmE(intf.SignImmE),
        .PCPlus4E(intf.PCPlus4E),
        .PCBranchE(intf.PCBranchE),
        .ALUControlE(intf.ALUControlE),
        .funct3E(intf.funct3E),
        .BranchE(intf.BranchE),
        .JumpE(intf.JumpE),
        .JalrE(intf.JalrE),
        .AuipcE(intf.AuipcE),
        .WordOpE(intf.WordOpE),
        .ForwardAE(intf.ForwardAE),
        .ForwardBE(intf.ForwardBE),
        .Rs1E(intf.Rs1E),
        .RdE(intf.RdE),
        .RegWriteE(intf.RegWriteE),
        .CsrAccessE(intf.CsrAccessE),
        .CsrOperationE(intf.CsrOperationE),
        .CsrIndexE(intf.CsrIndexE),
        .SelectorE(intf.SelectorE),
        .ALUSrcE(intf.ALUSrcE),
        .MemWriteE(intf.MemWriteE),
        .MemReadE(intf.MemReadE),
        .MRetE(intf.MRetE),
        .EcallE(intf.EcallE),
        .EbreakE(intf.EbreakE),
        .IllegaleInstructionE(intf.IllegaleInstructionE),
        .RdFE(intf.RdFE),
        .RD1FE(intf.RD1FE),
        .RD2FE(intf.RD2FE),
        .FPUControlE(intf.FPUControlE),
        .RoundModeE(intf.RoundModeE),
        .FPURegWriteE(intf.FPURegWriteE),
        .FPUValidE(intf.FPUValidE),
        .MoveOperationE(intf.MoveOperationE),
        .ForwardFloatingAE(intf.ForwardFloatingAE),
        .ForwardFloatingBE(intf.ForwardFloatingBE),
        .Rs1FE(intf.Rs1FE),
        .Rs2FE(intf.Rs2FE),
        .ResultW(intf.ResultW),
        .FPUOutW(intf.FPUOutW),
        .TimerInterrupt(intf.TimerInterrupt),
        .ExternalInterrupt(intf.ExternalInterrupt),
        .SoftwareInterrupt(intf.SoftwareInterrupt),
        .StallE(intf.StallE),
        .StallM(intf.StallM),
        .FlushM(intf.FlushM),
        .ValidM(intf.ValidM),
        .ALUOutM(intf.ALUOutM),
        .WriteDataM(intf.WriteDataM),
        .RdM(intf.RdM),
        .PCSrcE(intf.PCSrcE),
        .PCTargetE(intf.PCTargetE),
        .RegWriteM(intf.RegWriteM),
        .PCPlus4M(intf.PCPlus4M),
        .SelectorM(intf.SelectorM),
        .funct3M(intf.funct3M),
        .CsrOutM(intf.CsrOutM),
        .MemWriteM(intf.MemWriteM),
        .MemReadM(intf.MemReadM),
        .TrapIsSet(intf.TrapIsSet),
        .CsrOutPC(intf.CsrOutPC),
        .RdFM(intf.RdFM),
        .OverflowM(intf.OverflowM),
        .UnderflowM(intf.UnderflowM),
        .NaNM(intf.NaNM),
        .InfM(intf.InfM),
        .ZeroM(intf.ZeroM),
        .InvalidDivM(intf.InvalidDivM),
        .FPUOutM(intf.FPUOutM),
        .FPURegWriteM(intf.FPURegWriteM),
        .MoveOperationM(intf.MoveOperationM),
        .FPUBusyE(intf.FPUBusyE),
        .FPUDoneE(intf.FPUDoneE)
    );

    // ── Hazard-unit contract for a stand-alone EX stage ──────────────────────
    // A cache freeze (MemStallBit) holds EX and EX/MEM; an FP instruction
    // holds EX until the FPU is done and leaves a bubble in EX/MEM; a trap
    // squashes the EX instruction.
    logic FPUWait;
    always_comb
    begin
        FPUWait     = intf.FPUValidE && intf.ValidE && !intf.FPUDoneE;
        intf.StallE = intf.MemStallBit || FPUWait;
        intf.StallM = intf.MemStallBit;
        intf.FlushM = !intf.MemStallBit && (intf.TrapIsSet || FPUWait);
    end

    // Passive FPU and CSR sub-env taps (bound here, not inside the RTL).
    bind DUT.FPU flp_wr FPU_bind
    (
        .*
    );

    bind DUT.CSR csr_wr CSR_bind
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

        test_name = "execute_test";
        clp = uvm_cmdline_processor::get_inst();
        if (clp.get_arg_value("+UVM_TESTNAME=", test_name))
        begin
            if (test_name != "execute_test")
                test_name = "execute_test";
        end

        uvm_config_db #(virtual execute_interface)::set(null,"","INTF",intf);
        run_test(test_name);
    end

endmodule
