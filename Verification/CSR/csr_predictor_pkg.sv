// =============================================================================
// csr_predictor_pkg.sv
// -----------------------------------------------------------------------------
// Reference model (predictor) for the CSR file.
//
// CSR outputs (CsrOut, CsrOutPC, TrapIsSet) and RoundingMode are registered
// by the design. Predictor uses emit-before-update on a shadow copy of those
// outputs so the expected transaction lines up with the registered DUT
// outputs the monitor sampled this cycle. The CSR file image is also kept as
// shadow state and advanced for the next cycle.
// =============================================================================
package csr_predictor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import shared_pkg::*;
    import csr_item_pkg::*;
    `include "../../Design/csr_defs.sv"

    class csr_predictor extends uvm_subscriber #(csr_item);

        `uvm_component_utils(csr_predictor)

        function new (string name = "csr_predictor", uvm_component parent = null);
            super.new(name,parent);
        endfunction:new

        uvm_analysis_port #(csr_item) exp_port;
        csr_item shadow_input, exp_clone, exp;

        logic [FINAL_DATA_WIDTH-1:0] CsrFile [4096];

        logic [FINAL_ADDR_WIDTH-1:0] q_CsrOutPC;
        logic [FINAL_DATA_WIDTH-1:0] q_CsrOut;
        logic                        q_TrapIsSet;
        round_mode_t                 q_RoundingMode;

        logic [FINAL_ADDR_WIDTH-1:0] n_CsrOutPC;
        logic [FINAL_DATA_WIDTH-1:0] n_CsrOut;
        logic                        n_TrapIsSet;
        round_mode_t                 n_RoundingMode;

        virtual function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            exp_port = new("exp_port",this);
            exp = csr_item::type_id::create("exp");
            ResetCsrFile();
            reset_shadow();
        endfunction:build_phase

        virtual task reset_phase (uvm_phase phase);
            super.reset_phase(phase);
            ResetCsrFile();
            reset_shadow();
        endtask:reset_phase

        function void reset_shadow();
            q_CsrOutPC     = '0;
            q_CsrOut       = '0;
            q_TrapIsSet    = 1'b0;
            q_RoundingMode = RNE;
        endfunction:reset_shadow

        function void ResetCsrFile();
            foreach(CsrFile[i]) CsrFile[i] = '0;
            CsrFile[misa]      = 32'h40_00_01_00;
            CsrFile[mvendorid] = 32'h48_41_4E_4F;
            n_CsrOut       = '0;
            n_CsrOutPC     = '0;
            n_TrapIsSet    = 1'b0;
            n_RoundingMode = RNE;
        endfunction:ResetCsrFile

        function automatic logic [FINAL_DATA_WIDTH-1:0] TrapCause(input traps_t TrapCode);
            case(TrapCode)
                InstructionAddressMisalignedOrUserSoftwareInterrupt: TrapCause = 32'd0;
                InstructionAccessFaultOrSupervisorSoftwareInterrupt: TrapCause = 32'd1;
                IllegalInstructionOrHypervisorSoftwareInterrupt:     TrapCause = 32'd2;
                BreakpointOrMachineSoftwareInterrupt:                TrapCause = 32'd3;
                LoadAddressMisalignedOrUserSoftwareInterrupt:        TrapCause = 32'd4;
                LoadAddressFaultOrSupervisorTimerInterrupt:          TrapCause = 32'd5;
                StoreAddressMisalignedOrHyperVisorTimerInterrupt:    TrapCause = 32'd6;
                StoreAddressFaultOrMachineTimerInterrupt:            TrapCause = 32'd7;
                EcallUOrUserExternalInterrupt:                       TrapCause = 32'd8;
                EcallSOrSupervisorExternalInterrupt:                 TrapCause = 32'd9;
                EcallHOrHypervisorExternalInterrupt:                 TrapCause = 32'd10;
                EcallMOrMachineExternalInterrupt:                    TrapCause = 32'd11;
                default:                                             TrapCause = 32'd0;
            endcase
        endfunction:TrapCause

        function automatic logic [FINAL_ADDR_WIDTH-1:0] TrapVector(
            input logic                       Interrupt,
            input logic [FINAL_DATA_WIDTH-1:0] Cause);
            TrapVector = {CsrFile[mtvec][FINAL_ADDR_WIDTH-1:2], 2'b00};
            if(Interrupt && (CsrFile[mtvec][`MTVEC_MODE_END:`MTVEC_MODE_START] == `MTVEC_VECTORED))
                TrapVector = {CsrFile[mtvec][FINAL_ADDR_WIDTH-1:2], 2'b00}
                             + (Cause[FINAL_ADDR_WIDTH-1:0] << 2);
        endfunction:TrapVector

        function void UpdatePendingInterrupts(input csr_item act);
            CsrFile[mip][`MT_I] = act.TimerInterrupt;
            CsrFile[mip][`ME_I] = act.ExternalInterrupt;
            CsrFile[mip][`MS_I] = act.SoftwareInterrupt;
        endfunction:UpdatePendingInterrupts

        function automatic logic [FINAL_DATA_WIDTH-1:0] ReadCsr(input csr_index_t Index);
            ReadCsr = CsrFile[Index];
        endfunction:ReadCsr

        function void WriteCsr(input csr_index_t Index, input logic [FINAL_DATA_WIDTH-1:0] X);
            if(Index == mstatus)        CsrFile[Index] = X & `mstatus_mask;
            else if(Index == mtvec)     CsrFile[Index] = X & `mtvec_mask;
            else if(Index == mepc)      CsrFile[Index] = X & `align_mask;
            else if(Index == mscratch)  CsrFile[Index] = X;
            else if(Index == mie)       CsrFile[Index] = X & `mie_mask;
            else if(Index == mcause)    CsrFile[Index] = X & `mcause_mask;
            else if(Index == fflags) begin
                CsrFile[Index][4:0] = X[4:0];
                CsrFile[fcsr][4:0]  = X[4:0];
            end
            else if(Index == frm) begin
                CsrFile[Index][2:0] = X[2:0];
                CsrFile[fcsr][7:5]  = X[2:0];
            end
            else if(Index == fcsr) begin
                CsrFile[Index][7:0]  = X[7:0];
                CsrFile[fflags][4:0] = X[4:0];
                CsrFile[frm][2:0]    = X[7:5];
            end
            else if(!(Index inside {misa,mvendorid,mip}))
                CsrFile[Index] = X;
        endfunction:WriteCsr

        function void HandleTrapEntry(input csr_item act, input logic [FINAL_DATA_WIDTH-1:0] Cause, input logic Interrupt);
            CsrFile[mepc]            = act.PC & `align_mask;
            CsrFile[mstatus][`MPIE]  = CsrFile[mstatus][`MIE];
            CsrFile[mstatus][`MIE]   = 1'b0;
            CsrFile[mcause]          = {Interrupt, Cause[FINAL_DATA_WIDTH-2:0]};
            n_CsrOutPC               = TrapVector(Interrupt, Cause);
            n_TrapIsSet              = 1'b1;
        endfunction:HandleTrapEntry

        function void HandleException(input csr_item act);
            HandleTrapEntry(act, TrapCause(act.Traps), 1'b0);
            CsrFile[mbadaddr] = act.Address;
        endfunction:HandleException

        function void HandleInterrupt(input csr_item act, input logic [FINAL_DATA_WIDTH-1:0] Cause);
            HandleTrapEntry(act, Cause, 1'b1);
        endfunction:HandleInterrupt

        function void HandleReturn();
            n_CsrOutPC              = CsrFile[mepc][FINAL_ADDR_WIDTH-1:0] & `align_mask;
            CsrFile[mstatus][`MIE]  = CsrFile[mstatus][`MPIE];
            CsrFile[mstatus][`MPIE] = 1'b1;
            n_TrapIsSet             = 1'b0;
        endfunction:HandleReturn

        function automatic logic ExternalInterruptSet(input csr_item act);
            ExternalInterruptSet = CsrFile[mstatus][`MIE]
                                 & CsrFile[mie][`ME_I]
                                 & (CsrFile[mip][`ME_I] | act.ExternalInterrupt);
        endfunction:ExternalInterruptSet

        function automatic logic SoftwareInterruptSet(input csr_item act);
            SoftwareInterruptSet = CsrFile[mstatus][`MIE]
                                 & CsrFile[mie][`MS_I]
                                 & (CsrFile[mip][`MS_I] | act.SoftwareInterrupt);
        endfunction:SoftwareInterruptSet

        function automatic logic TimerInterruptSet(input csr_item act);
            TimerInterruptSet = CsrFile[mstatus][`MIE]
                              & CsrFile[mie][`MT_I]
                              & (CsrFile[mip][`MT_I] | act.TimerInterrupt);
        endfunction:TimerInterruptSet

        function void HandleCsrAccess(input csr_item act);
            logic [FINAL_DATA_WIDTH-1:0] OldValue, SourceValue;
            OldValue    = ReadCsr(act.CsrIndex);
            SourceValue = act.CsrIn;
            n_CsrOut    = OldValue;
            case(act.CsrOperation)
                csrrw:                       WriteCsr(act.CsrIndex, SourceValue);
                csrrs:  if(act.Rs != '0) WriteCsr(act.CsrIndex, OldValue | SourceValue);
                csrrc:  if(act.Rs != '0) WriteCsr(act.CsrIndex, OldValue & ~SourceValue);
                csrrwi:                      WriteCsr(act.CsrIndex, {27'b0, act.Rs});
                csrrsi: if(act.Rs != '0) WriteCsr(act.CsrIndex, OldValue | {27'b0, act.Rs});
                csrrci: if(act.Rs != '0) WriteCsr(act.CsrIndex, OldValue & ~{27'b0, act.Rs});
            endcase
        endfunction:HandleCsrAccess

        function void compute_next(input csr_item act);
            if(act.Traps != NoTraps)               
                HandleException(act);
            else if(act.mret)                      
                HandleReturn();
            else if(ExternalInterruptSet(act))            
                HandleInterrupt(act, `MACHINE_EXTERNAL_INTERRUPT_CAUSE);
            else if(SoftwareInterruptSet(act))            
                HandleInterrupt(act, `MACHINE_SOFTWARE_INTERRUPT_CAUSE);
            else if(TimerInterruptSet(act))               
                HandleInterrupt(act, `MACHINE_TIMER_INTERRUPT_CAUSE);
            else if(act.CsrAccess) 
            begin
                HandleCsrAccess(act);
                n_TrapIsSet = 1'b0;
            end
            else 
            begin
                n_CsrOut    = '0;
                n_TrapIsSet = 1'b0;
            end
            UpdatePendingInterrupts(act);
            n_RoundingMode = round_mode_t'(CsrFile[frm][2:0]);
        endfunction:compute_next

        virtual function void write (csr_item t);
            // Async active-low rst: DUT registered outputs and the CsrFile
            // are cleared immediately, so emit reset defaults this cycle.
            // This is the only signal allowed to "update before emit".
            if(!t.rst)
            begin
                ResetCsrFile();
                reset_shadow();
            end

            exp.CsrOutPC     = q_CsrOutPC;
            exp.CsrOut       = q_CsrOut;
            exp.TrapIsSet    = q_TrapIsSet;
            exp.RoundingMode = q_RoundingMode;
            if(!(shadow_input == null))
                exp.copy_inputs(shadow_input);
            if(!$cast(exp_clone, exp.clone()))
                `uvm_fatal("CSR_PRED", "Failed to clone expected item - check for non-cloneable fields")
            else
                exp_port.write(exp_clone);
            
            if(t.rst)
            begin
                compute_next(t);
                q_CsrOutPC     = n_CsrOutPC;
                q_CsrOut       = n_CsrOut;
                q_TrapIsSet    = n_TrapIsSet;
                q_RoundingMode = n_RoundingMode;
            end
            if(!$cast(shadow_input, t.clone()))
                `uvm_fatal("CSR_PRED", "Failed to clone input item for shadow - check for non-cloneable fields")
        endfunction:write

    endclass:csr_predictor

endpackage:csr_predictor_pkg
