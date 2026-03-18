package csr_scoreboard_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import csr_item_pkg::*;
    `include "../../Design/csr_defs.sv"

    class csr_scoreboard extends uvm_scoreboard;

        logic [FINAL_DATA_WIDTH-1:0] CsrFile [4096];
        logic [FINAL_ADDR_WIDTH-1:0] CsrOutPC;
        logic [FINAL_DATA_WIDTH-1:0] CsrOut;
        logic TrapIsSet;
        round_mode_t RoundingMode;

        int success,fail;

        `uvm_component_utils(csr_scoreboard)

        function new (string name = "csr_scoreboard", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        csr_item sc_item;
        uvm_analysis_imp #(csr_item , csr_scoreboard) sc_port;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            sc_port = new("sc_port",this);
        endfunction:build_phase

        function void ResetCsrFile();
            foreach(CsrFile[i])
                CsrFile[i] = 'b0;
            CsrFile[misa] = 32'h40_00_01_00;
            CsrFile[mvendorid] = 32'h48_41_4E_4F;
            CsrOut = 'b0;
            CsrOutPC = 'b0;
            TrapIsSet = 'b0;
            RoundingMode = RNE;
        endfunction:ResetCsrFile

        function automatic logic [FINAL_DATA_WIDTH-1:0] TrapCause(input traps_t TrapCode);
            case(TrapCode)
                InstructionAddressMisalignedOrUserSoftwareInterrupt: TrapCause = 32'd0;
                InstructionAccessFaultOrSupervisorSoftwareInterrupt: TrapCause = 32'd1;
                IllegalInstructionOrHypervisorSoftwareInterrupt: TrapCause = 32'd2;
                BreakpointOrMachineSoftwareInterrupt: TrapCause = 32'd3;
                LoadAddressMisalignedOrUserSoftwareInterrupt: TrapCause = 32'd4;
                LoadAddressFaultOrSupervisorTimerInterrupt: TrapCause = 32'd5;
                StoreAddressMisalignedOrHyperVisorTimerInterrupt: TrapCause = 32'd6;
                StoreAddressFaultOrMachineTimerInterrupt: TrapCause = 32'd7;
                EcallUOrUserExternalInterrupt: TrapCause = 32'd8;
                EcallSOrSupervisorExternalInterrupt: TrapCause = 32'd9;
                EcallHOrHypervisorExternalInterrupt: TrapCause = 32'd10;
                EcallMOrMachineExternalInterrupt: TrapCause = 32'd11;
                default: TrapCause = 32'd0;
            endcase
        endfunction:TrapCause

        function automatic logic [FINAL_ADDR_WIDTH-1:0] TrapVector(input logic Interrupt, input logic [FINAL_DATA_WIDTH-1:0] Cause);
            TrapVector = {CsrFile[mtvec][FINAL_ADDR_WIDTH-1:2], 2'b00};
            if(Interrupt && (CsrFile[mtvec][`MTVEC_MODE_END:`MTVEC_MODE_START] == `MTVEC_VECTORED))
                TrapVector = {CsrFile[mtvec][FINAL_ADDR_WIDTH-1:2], 2'b00} + (Cause[FINAL_ADDR_WIDTH-1:0] << 2);
        endfunction:TrapVector

        function void UpdatePendingInterrupts();
            CsrFile[mip][`MT_I] = sc_item.TimerInterrupt;
            CsrFile[mip][`ME_I] = sc_item.ExternalInterrupt;
            CsrFile[mip][`MS_I] = sc_item.SoftwareInterrupt;
        endfunction:UpdatePendingInterrupts

        function automatic logic [FINAL_DATA_WIDTH-1:0] ReadCsr(input csr_index_t Index);
            ReadCsr = CsrFile[Index];
        endfunction:ReadCsr

        function void WriteCsr(input csr_index_t Index, input logic [FINAL_DATA_WIDTH-1:0] X);
            if(Index == mstatus)
                CsrFile[Index] = X & `mstatus_mask;
            else if(Index == mtvec)
                CsrFile[Index] = X & `mtvec_mask;
            else if(Index == mepc)
                CsrFile[Index] = X & `align_mask;
            else if(Index == mscratch)
                CsrFile[Index] = X;
            else if(Index == mie)
                CsrFile[Index] = X & `mie_mask;
            else if(Index == mcause)
                CsrFile[Index] = X & `mcause_mask;
            else if(Index == fflags)
            begin
                CsrFile[Index][4:0] = X[4:0];
                CsrFile[fcsr][4:0] = X[4:0];
            end
            else if(Index == frm)
            begin
                CsrFile[Index][2:0] = X[2:0];
                CsrFile[fcsr][7:5] = X[2:0];
            end
            else if(Index == fcsr)
            begin
                CsrFile[Index][7:0] = X[7:0];
                CsrFile[fflags][4:0] = X[4:0];
                CsrFile[frm][2:0] = X[7:5];
            end
            else if(!(Index inside {misa,mvendorid,mip}))
                CsrFile[Index] = X;
        endfunction:WriteCsr

        function void HandleTrapEntry(input logic [FINAL_DATA_WIDTH-1:0] Cause, input logic Interrupt);
            CsrFile[mepc] = sc_item.PC & `align_mask;
            CsrFile[mstatus][`MPIE] = CsrFile[mstatus][`MIE];
            CsrFile[mstatus][`MIE] = 1'b0;
            CsrFile[mcause] = {Interrupt, Cause[FINAL_DATA_WIDTH-2:0]};
            CsrOutPC = TrapVector(Interrupt, Cause);
            TrapIsSet = 1'b1;
        endfunction:HandleTrapEntry

        function void HandleException();
            HandleTrapEntry(TrapCause(sc_item.Traps), 1'b0);
            CsrFile[mbadaddr] = sc_item.Address;
        endfunction:HandleException

        function void HandleInterrupt(input logic [FINAL_DATA_WIDTH-1:0] Cause);
            HandleTrapEntry(Cause, 1'b1);
        endfunction:HandleInterrupt

        function void HandleReturn();
            CsrOutPC = CsrFile[mepc][FINAL_ADDR_WIDTH-1:0] & `align_mask;
            CsrFile[mstatus][`MIE] = CsrFile[mstatus][`MPIE];
            CsrFile[mstatus][`MPIE] = 1'b1;
            TrapIsSet = 1'b0;
        endfunction:HandleReturn

        function automatic logic ExternalInterruptSet();
            ExternalInterruptSet = CsrFile[mstatus][`MIE] & CsrFile[mie][`ME_I] & (CsrFile[mip][`ME_I] | sc_item.ExternalInterrupt);
        endfunction:ExternalInterruptSet

        function automatic logic SoftwareInterruptSet();
            SoftwareInterruptSet = CsrFile[mstatus][`MIE] & CsrFile[mie][`MS_I] & (CsrFile[mip][`MS_I] | sc_item.SoftwareInterrupt);
        endfunction:SoftwareInterruptSet

        function automatic logic TimerInterruptSet();
            TimerInterruptSet = CsrFile[mstatus][`MIE] & CsrFile[mie][`MT_I] & (CsrFile[mip][`MT_I] | sc_item.TimerInterrupt);
        endfunction:TimerInterruptSet

        function void HandleCsrAccess();
            logic [FINAL_DATA_WIDTH-1:0] OldValue;
            logic [FINAL_DATA_WIDTH-1:0] SourceValue;
            OldValue = ReadCsr(sc_item.CsrIndex);
            SourceValue = sc_item.CsrIn;
            CsrOut = OldValue;
            case(sc_item.CsrOperation)
                csrrw:
                    WriteCsr(sc_item.CsrIndex, SourceValue);
                csrrs:
                    if(sc_item.Rs != 'b0)
                        WriteCsr(sc_item.CsrIndex, OldValue | SourceValue);
                csrrc:
                    if(sc_item.Rs != 'b0)
                        WriteCsr(sc_item.CsrIndex, OldValue & ~SourceValue);
                csrrwi:
                    WriteCsr(sc_item.CsrIndex, {27'b0, sc_item.Rs});
                csrrsi:
                    if(sc_item.Rs != 'b0)
                        WriteCsr(sc_item.CsrIndex, OldValue | {27'b0, sc_item.Rs});
                csrrci:
                    if(sc_item.Rs != 'b0)
                        WriteCsr(sc_item.CsrIndex, OldValue & ~{27'b0, sc_item.Rs});
            endcase
        endfunction:HandleCsrAccess

        function void ref_model ();
            if(!sc_item.rst)
            begin
                ResetCsrFile();
            end
            else
            begin
                RoundingMode = round_mode_t'(CsrFile[frm][2:0]);
                if(sc_item.Traps != NoTraps)
                begin
                    HandleException();
                end
                else if(sc_item.mret)
                begin
                    HandleReturn();
                end
                else if(ExternalInterruptSet())
                begin
                    HandleInterrupt(`MACHINE_EXTERNAL_INTERRUPT_CAUSE);
                end
                else if(SoftwareInterruptSet())
                begin
                    HandleInterrupt(`MACHINE_SOFTWARE_INTERRUPT_CAUSE);
                end
                else if(TimerInterruptSet())
                begin
                    HandleInterrupt(`MACHINE_TIMER_INTERRUPT_CAUSE);
                end
                else if(sc_item.CsrAccess)
                begin
                    HandleCsrAccess();
                    TrapIsSet = 1'b0;
                end
                else
                begin
                    CsrOut = 0;
                    TrapIsSet = 1'b0;
                end
                UpdatePendingInterrupts();
            end
        endfunction:ref_model

        function void check_output ();
            ref_model();
            if(
                sc_item.CsrOutPC != CsrOutPC ||
                sc_item.CsrOut != CsrOut ||
                sc_item.TrapIsSet != TrapIsSet ||
                sc_item.RoundingMode != RoundingMode
            )
            begin
                $display("//////////////////////Error occured in the CSR scoreboard//////////////////////");
                `uvm_info("SCB",sc_item.convert2str(),UVM_MEDIUM)
                if(sc_item.CsrOutPC != CsrOutPC)
                begin
                    `uvm_info("SCB",$sformatf("Actual output CsrOutPC = %0h -- Expected CsrOutPC = %0h",sc_item.CsrOutPC,CsrOutPC),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.CsrOut != CsrOut)
                begin
                    `uvm_info("SCB",$sformatf("Actual output CsrOut = %0h -- Expected CsrOut = %0h",sc_item.CsrOut,CsrOut),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.TrapIsSet != TrapIsSet)
                begin
                    `uvm_info("SCB",$sformatf("Actual output TrapIsSet = %0b -- Expected TrapIsSet = %0b",sc_item.TrapIsSet,TrapIsSet),UVM_MEDIUM)
                    fail++;
                end
                if(sc_item.RoundingMode != RoundingMode)
                begin
                    `uvm_info("SCB",$sformatf("Actual output RoundingMode = %s -- Expected RoundingMode = %s",sc_item.RoundingMode.name(),RoundingMode.name()),UVM_MEDIUM)
                    fail++;
                end
            end
            else
            begin
                success++;
            end
        endfunction

        function void write (csr_item item);
            sc_item = item;
            check_output();
        endfunction

        virtual function void report_phase (uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB","CSR Scoreboard report",UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Success count = %0d",success),UVM_MEDIUM)
            `uvm_info("SCB",$sformatf("Actual Fail count = %0d",fail),UVM_MEDIUM)
        endfunction

    endclass:csr_scoreboard

endpackage:csr_scoreboard_pkg
