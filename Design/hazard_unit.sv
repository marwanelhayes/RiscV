// =============================================================================
// hazard_unit.sv
// -----------------------------------------------------------------------------
// Hazard detection and forwarding unit for RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Detect load-use hazards (stall F/D, bubble into EX)
//   - Hold an FP instruction in EX until the FPU is done (stall F/D/EX,
//     bubble into MEM)
//   - Freeze every stage while either cache misses
//   - Generate forwarding selects for GPR operands (MEM before WB)
//   - Generate forwarding selects for FPR operands (f0 included)
//   - Generate pipeline flush signals for redirects and traps
//
// Only this unit computes stalls and flushes. A redirect (taken branch, jump,
// trap, MRET) is only raised by EX when it advances, so a flush never races a
// stall of the same stage.
// =============================================================================
import shared_pkg::*;

module hazard_unit 
(
    // ─── Execute stage register indices ───────────────────────────────────────
    input   gpr_t Rs1E,               // Source register 1 (execute)
    input   gpr_t Rs2E,               // Source register 2 (execute)
    input   gpr_t RdE,                // Destination register (execute)

    // ─── Decode stage register indices ────────────────────────────────────────
    input   gpr_t Rs1D,               // Source register 1 (decode, x0 if unused)
    input   gpr_t Rs2D,               // Source register 2 (decode, x0 if unused)

    // ─── Memory/Write-back register indices ───────────────────────────────────
    input   gpr_t RdM,                // Destination register (memory)
    input   gpr_t RdW,                // Destination register (writeback)

    // ─── Register write enables ───────────────────────────────────────────────
    input   logic RegWriteM,          // GPR write enable (memory)
    input   logic RegWriteW,          // GPR write enable (writeback)

    // ─── Control signals ───────────────────────────────────────────────────────
    input   selector_t SelectorE,     // Write-back select (execute)
    input   logic PCSrcE,            // Taken branch/jump redirect
    input   logic TrapIsSet,         // Trap/MRET redirect

    // ─── FPR indices ───────────────────────────────────────────────────────────
    input   fpr_t RdFM,              // FPR destination (memory)
    input   fpr_t RdFW,              // FPR destination (writeback)
    input   fpr_t Rs1FE,             // FPR source 1 (execute)
    input   fpr_t Rs2FE,             // FPR source 2 (execute)

    // ─── FPR write enables ───────────────────────────────────────────────────
    input   logic FPURegWriteM,      // FPR write enable (memory)
    input   logic FPURegWriteW,      // FPR write enable (writeback)

    // ─── FPU status ───────────────────────────────────────────────────────────
    input   logic FPUValidE,         // FP instruction in EX
    input   logic FPUDoneE,          // FPU result valid this cycle

    // ─── Cache status ───────────────────────────────────────────────────────────
    input   logic ICacheHit,         // Instruction cache hit
    input   logic DCacheHit,         // Data cache hit

    // ─── Forwarding outputs ───────────────────────────────────────────────────
    output  logic [2:0] ForwardAE,    // GPR operand A forward select
    output  logic [2:0] ForwardBE,    // GPR operand B forward select
    output  logic [1:0] ForwardFloatingAE,  // FPR operand A forward select
    output  logic [1:0] ForwardFloatingBE,  // FPR operand B forward select

    // ─── Pipeline control outputs ─────────────────────────────────────────────
    output  logic StallF,            // Hold the PC
    output  logic StallD,            // Hold IF/ID
    output  logic StallE,            // Hold ID/EX (EX instruction does not advance)
    output  logic StallM,            // Hold EX/MEM
    output  logic StallW,            // Hold MEM/WB
    output  logic FlushD,            // Bubble into IF/ID
    output  logic FlushE,            // Bubble into ID/EX
    output  logic FlushM             // Bubble into EX/MEM
);

    // ─── Internal registers – hazard detection flags ─────────────────────────
    logic LWStall,FPUStall,MemStall,Redirect;

    // ─── Load-Use hazard detection ───────────────────────────────────────────
    always_comb 
    begin
        LWStall = 1'b0;
        if ((SelectorE == MemToReg) && (RdE != zero) && ((RdE == Rs1D) || (RdE == Rs2D))) 
        begin
            LWStall = 1'b1;    // Load result not yet available
        end
    end

    // ─── FPU busy hazard detection ───────────────────────────────────────────
    always_comb
    begin
        FPUStall = FPUValidE && !FPUDoneE;    // FP instruction waits in EX for its result
        MemStall = !ICacheHit || !DCacheHit;  // Any miss freezes the whole pipeline
        Redirect = PCSrcE || TrapIsSet;
    end

    // ─── GPR operand A forwarding (youngest producer first) ─────────────────
    always_comb
    begin
        ForwardAE = 3'b000; 
        if (RegWriteM && (RdM != zero) && (RdM == Rs1E)) 
        begin
            ForwardAE = 3'b010;    // Forward from MEM stage
        end
        else if (RegWriteW && (RdW != zero) && (RdW == Rs1E)) 
        begin
            ForwardAE = 3'b001;    // Forward from WB stage
        end
    end

    // ─── GPR operand B forwarding ────────────────────────────────────────────
    always_comb
    begin
        ForwardBE = 3'b000;
        if (RegWriteM && (RdM != zero) && (RdM == Rs2E)) 
        begin
            ForwardBE = 3'b010;
        end
        else if (RegWriteW && (RdW != zero) && (RdW == Rs2E)) 
        begin
            ForwardBE = 3'b001;
        end
    end

    // ─── FPR operand A forwarding (f0 is a real register) ───────────────────
    always_comb
    begin
        ForwardFloatingAE = 2'b00;
        if (FPURegWriteM && (RdFM == Rs1FE)) 
        begin
            ForwardFloatingAE = 2'b10;
        end
        else if (FPURegWriteW && (RdFW == Rs1FE)) 
        begin
            ForwardFloatingAE = 2'b01;
        end 
    end

    // ─── FPR operand B forwarding ────────────────────────────────────────────
    always_comb
    begin
        ForwardFloatingBE = 2'b00;
        if (FPURegWriteM && (RdFM == Rs2FE)) 
        begin
            ForwardFloatingBE = 2'b10;
        end
        else if (FPURegWriteW && (RdFW == Rs2FE)) 
        begin
            ForwardFloatingBE = 2'b01;
        end 
    end
        
    // ─── Pipeline stall and flush generation ────────────────────────────────
    always_comb
    begin
        StallF = MemStall || FPUStall || LWStall;
        StallD = MemStall || FPUStall || LWStall;
        StallE = MemStall || FPUStall;
        StallM = MemStall;
        StallW = MemStall;
        FlushD = Redirect;
        FlushE = Redirect || (LWStall && !StallE);
        FlushM = TrapIsSet || (FPUStall && !MemStall);
    end
endmodule
