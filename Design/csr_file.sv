import shared_pkg::*;
`include "csr_defs.sv"

module csr_file
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input clk,
    input rst,
    input csr_t CsrOperation,
    input [4:0] Rs,
    input traps_t Traps,
    input mret,
    input [ADDR_WIDTH-1:0] PC,
    input [ADDR_WIDTH-1:0] Address,
    input CsrAccess,
    input [DATA_WIDTH-1:0] CsrIn,
    input TimerInterrupt,
    input ExternalInterrupt,
    input SoftwareInterrupt,
    input csr_index_t CsrIndex,
    
    output logic [ADDR_WIDTH-1:0] CsrOutPC,
    output logic [DATA_WIDTH-1:0] CsrOut,
    output logic TrapIsSet,
    output round_mode_t RoundingMode
);

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] CsrFile [4096]; // CSR file with 4096 entries, each 32 bits wide
    wire PendingInterrupt;
    wire CurrentInterrupt;
    wire AllInterrupts;

    assign PendingInterrupt = (CsrFile[mstatus][`MIE] & CsrFile[mip][`ME_PIE]) || (CsrFile[mstatus][`MIE] & CsrFile[mip][`MT_PIE]) || (CsrFile[mstatus][`MIE] & CsrFile[mip][`MS_PIE]) ; 

    assign CurrentInterrupt = (TimerInterrupt & CsrFile[mstatus][`MIE] & CsrFile[mie][`MT_PIE]) || ( ExternalInterrupt & CsrFile[mstatus][`MIE] & CsrFile[mie][`ME_PIE]) || (SoftwareInterrupt & CsrFile[mstatus][`MIE] & CsrFile[mie][`MS_PIE]) ; 

    assign AllInterrupts = TimerInterrupt | ExternalInterrupt | SoftwareInterrupt;

    function void ResetCsrFile;
        CsrFile[mstatus] <= 0;
        CsrFile[misa] <= 32'h40_00_01_00;
        CsrFile[medeleg] <= 0;
        CsrFile[mideleg] <= 0;
        CsrFile[mie] <= 0;
        CsrFile[mtvec] <= 0;
        CsrFile[mscratch] <= 0;
        CsrFile[mepc] <= 0;
        CsrFile[mcause] <= 0;
        CsrFile[mbadaddr] <= 0;
        CsrFile[mip] <= 0;
        CsrFile[mcycle] <= 0;
        CsrFile[mhartid] <= 0;
        CsrFile[mvendorid] <= 32'h48_41_4E_4F;
        CsrOut <= 0;
        CsrOutPC <= 0;
        TrapIsSet <= 1'b0;
    endfunction:ResetCsrFile

    function void HandleInterrupt;
        CsrFile[mepc] <= PC; // Set mepc to current PC on interrupt
        TrapIsSet <= 1'b1;
        CsrFile[mstatus][`MPIE] <= CsrFile[mstatus][`MIE];
        CsrFile[mstatus][`MIE] <= 1'b0;
    endfunction:HandleInterrupt

    function void HandleException;
        HandleInterrupt();
        CsrFile[mcause] <= {20'b0, Traps};
        CsrOutPC <= CsrFile[mtvec];
        CsrFile[mbadaddr] <= Address;
    endfunction:HandleException

    function void HandleReturn;
        CsrOutPC <= CsrFile[mepc];
        CsrFile[mstatus][`MIE] <= CsrFile[mstatus][`MPIE];
        CsrFile[mstatus][`MPIE] <= 1'b1;
        TrapIsSet <= 1'b0;
    endfunction:HandleReturn

    function void UpdateCsr(input logic [DATA_WIDTH-1:0] X);
        if(CsrIndex == mstatus)
            CsrFile[CsrIndex] <= X & `mstatus_mask;
        else if(CsrIndex == mtvec)
            CsrFile[CsrIndex] <= X & `align_mask;
        else if(CsrIndex == mepc)
            CsrFile[CsrIndex] <= X & `align_mask;
        else if(CsrIndex == mscratch)
            CsrFile[CsrIndex] <= X & `align_mask;
        else if(CsrIndex == mie)
            CsrFile[CsrIndex] <= X & `mie_mask;
        else if(CsrIndex == mip)
            CsrFile[CsrIndex] <= X & `mpie_mask;
        else if(CsrIndex == mcause)
            CsrFile[CsrIndex] <= CsrFile[CsrIndex];
        else if (CsrIndex == fflags)
        begin
            CsrFile[CsrIndex][4:0] <= X;
            CsrFile[fcsr][4:0] <= X;
        end
        else if( CsrIndex == frm)
        begin
            CsrFile[CsrIndex][2:0] <= X;
            CsrFile[fcsr][7:5] <= X;
        end
        else if( CsrIndex == fcsr)
        begin
            CsrFile[CsrIndex][7:0] <= X;
        end
        else if(CsrIndex != misa || CsrIndex != mvendorid)
            CsrFile[CsrIndex] <= X;
    endfunction:UpdateCsr

    function void PutInterruptPending;
        if(TimerInterrupt)
            CsrFile[mip][`MT_PIE] <= 1'b1;
        if(ExternalInterrupt)
            CsrFile[mip][`ME_PIE] <= 1'b1;
        if(SoftwareInterrupt)
            CsrFile[mip][`MS_PIE] <= 1'b1;
    endfunction:PutInterruptPending

    initial 
    begin
        foreach (CsrFile[i]) 
        begin
            CsrFile[i] = 0;
        end
    end

    always_ff @(posedge clk or negedge rst or posedge AllInterrupts) 
    begin:CSR_File
        if (!rst) 
        begin:Reset
            ResetCsrFile();
        end:Reset
        
        else if(AllInterrupts)
        begin:Interrupts
            if(CurrentInterrupt)
            begin:Interrupt_Handling
                HandleInterrupt();
                PutInterruptPending();
                if(TimerInterrupt)
                begin:Timer_Interrupt
                    CsrOutPC <= CsrFile[mtvec] + 4 * `MT_PIE; // Set mcause to timer interrupt
                    CsrFile[mcause] <= {20'b0, StoreAddressFaultOrMachineTimerInterrupt};
                end:Timer_Interrupt
                
                else if(ExternalInterrupt)
                begin:External_Interrupt
                    CsrOutPC <= CsrFile[mtvec] + 4 * `ME_PIE; // Set mcause to external interrupt
                    CsrFile[mcause] <= {20'b0, EcallMOrMachineExternalInterrupt};
                end:External_Interrupt
                
                else if(SoftwareInterrupt)
                begin:Software_Interrupt
                    CsrOutPC <= CsrFile[mtvec] + 4 * `MS_PIE; // Set mcause to software interrupt
                    CsrFile[mcause] <= {20'b0, BreakpointOrMachineSoftwareInterrupt};
                end:Software_Interrupt
            end:Interrupt_Handling
        end:Interrupts
        
        else
        begin:Not_interrupt
            if(PendingInterrupt)
            begin:Handle_Pending_Interrupts
                HandleInterrupt();
                if(CsrFile[mip][`MT_PIE])
                begin:Timer_Interrupt
                    CsrOutPC <= CsrFile[mtvec] + 4 * `MT_PIE; // Set mcause to timer interrupt
                    CsrFile[mcause] <= {20'b0, StoreAddressFaultOrMachineTimerInterrupt};
                    CsrFile[mip][`MT_PIE] <= 1'b0;
                    if(ExternalInterrupt)
                        CsrFile[mip][`ME_PIE] <= 1'b1;
                    if(SoftwareInterrupt)
                        CsrFile[mip][`MS_PIE] <= 1'b1;
                end:Timer_Interrupt
                
                else if(CsrFile[mstatus][`MIE] & CsrFile[mip][`ME_PIE])
                begin:External_Interrupt
                    CsrOutPC <= CsrFile[mtvec] + 4 * `ME_PIE; // Set mcause to external interrupt
                    CsrFile[mcause] <= {20'b0, EcallMOrMachineExternalInterrupt};
                    CsrFile[mip][`ME_PIE] <= 1'b0;
                    if(TimerInterrupt)
                        CsrFile[mip][`MT_PIE] <= 1'b1;
                    if(SoftwareInterrupt)
                        CsrFile[mip][`MS_PIE] <= 1'b1;
                end:External_Interrupt
                
                else if(CsrFile[mip][`MS_PIE])
                begin:Software_Interrupt
                    CsrOutPC <= CsrFile[mtvec] + 4 * `MS_PIE; // Set mcause to software interrupt
                    CsrFile[mcause] <= {20'b0, BreakpointOrMachineSoftwareInterrupt};
                    CsrFile[mip][`MS_PIE] <= 1'b0;
                    if(TimerInterrupt)
                        CsrFile[mip][`MT_PIE] <= 1'b1;
                    if(ExternalInterrupt)
                        CsrFile[mip][`ME_PIE] <= 1'b1;
                end:Software_Interrupt
            end:Handle_Pending_Interrupts
            
            else if (|(int'(Traps)))
            begin:Exception_Handling
                PutInterruptPending();
                HandleException();
            end:Exception_Handling
            
            else if(mret)
            begin:Return_From_Trap
                PutInterruptPending();
                HandleReturn();
                if(CsrFile[mstatus][`MPIE])
                begin:Delete_Pending
                    if(CsrFile[mcause] == {20'b0, EcallMOrMachineExternalInterrupt})
                    begin
                        CsrFile[mip][`ME_PIE] <= 1'b0;
                    end
                    else if(CsrFile[mcause] == {20'b0, BreakpointOrMachineSoftwareInterrupt})
                    begin
                        CsrFile[mip][`MS_PIE] <= 1'b0;
                    end
                    else if(CsrFile[mcause] == {20'b0, StoreAddressFaultOrMachineTimerInterrupt})
                    begin
                        CsrFile[mip][`MT_PIE] <= 1'b0;
                    end
                end:Delete_Pending
            end:Return_From_Trap
            
            else if (CsrAccess && !Traps) 
            begin:CSR_Access
                PutInterruptPending();
                CsrOut <= CsrFile[CsrIndex];
                TrapIsSet <= 1'b0;
                case(CsrOperation)   
                    csrrw: 
                    begin:CSR_RW
                        UpdateCsr(CsrIn);
                    end:CSR_RW
                    
                    csrrs: 
                    begin:CSR_Set
                        UpdateCsr(CsrIn | CsrFile[CsrIndex]);
                    end:CSR_Set
                    
                    csrrc: 
                    begin:CSR_Clear
                        UpdateCsr(CsrIn &  ~CsrFile[CsrIndex]);
                    end:CSR_Clear
                    
                    csrrwi: 
                    begin:Write_Immediate
                        UpdateCsr({27'b0, Rs});
                    end:Write_Immediate
                    
                    csrrsi: 
                    begin:Set_Immediate
                        UpdateCsr(CsrFile[CsrIndex] | {27'b0, Rs});
                    end:Set_Immediate
                    
                    csrrci: 
                    begin:Clear_Immediate
                        UpdateCsr(CsrFile[CsrIndex] & ~{27'b0, Rs});
                    end:Clear_Immediate
                endcase
            end:CSR_Access
            
            else
            begin:No_Operation
                PutInterruptPending();
                TrapIsSet <= 1'b0;
            end:No_Operation
        
        end:Not_interrupt
    
    end:CSR_File

    assign RoundingMode = round_mode_t'(CsrFile[frm][2:0]);


endmodule