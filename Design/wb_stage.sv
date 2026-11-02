// =============================================================================
// wb_stage.sv
// -----------------------------------------------------------------------------
// Write-Back stage of the RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Select correct write-back data based on instruction type
//   - Update program counter with branch/jump target or next sequential
//   - Handle trap entry by redirecting PC to trap vector
//   - Manage pipeline stall from fetch stage
//
// Redirects (TrapIsSet, PCSrcE) are only raised when the EX instruction
// advances, so they always win over StallF and are never lost.
// =============================================================================
import shared_pkg::*;

module wb_stage
#(
    parameter int DATA_WIDTH = 32,      // XLEN (also the PC width)
    parameter int ADDR_WIDTH = 32       // Physical address width (unused here)
) 
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ── Branch/jump redirect from EX stage ───────────────────────────────────
    input PCSrcE,                               // Branch/jump taken
    input [DATA_WIDTH-1:0] PCBranchE,          // Branch/jump target address

    // ── Pipeline control from hazard unit ────────────────────────────────────
    input StallF,                              // Stall fetch stage
    input [DATA_WIDTH-1:0] PCPlus4F,          // Next sequential PC

    // ── Write-back data inputs ───────────────────────────────────────────────
    input [DATA_WIDTH-1:0] ALUOutW,            // ALU result
    input [DATA_WIDTH-1:0] ReadDataW,         // Loaded data from memory
    input selector_t SelectorW,                // Write-back source select

    // ── CSR and trap interface ────────────────────────────────────────────────
    input logic [DATA_WIDTH-1:0] CsrOutPC,     // Trap vector or mepc
    input logic TrapIsSet,                    // Trap/MRET redirect this cycle
    input [DATA_WIDTH-1:0] PCPlus4W,          // PC+4 (link value)
    input [DATA_WIDTH-1:0] CsrOutW,           // CSR read data

    // ── Outputs ───────────────────────────────────────────────────────────────
    output logic [DATA_WIDTH-1:0] ResultW,    // Final write-back result
    output logic [DATA_WIDTH-1:0] PCF         // PC for fetch stage
);

    // ─── Write-back data selection ───────────────────────────────────────────
    always_comb
    begin
        ResultW = '0;
        case(SelectorW)
            // ── ALU result to register ───────────────────────────────────────
            ALUToReg: ResultW = ALUOutW;
            // ── Memory load to register ──────────────────────────────────────
            MemToReg: ResultW = ReadDataW;
            // ── CSR to register ─────────────────────────────────────────────
            CSRToReg: ResultW = CsrOutW;
            // ── PC+4 to register (JAL) ───────────────────────────────────────
            PCToReg : ResultW = PCPlus4W;
        endcase
    end

    // ─── PC register update ───────────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst) 
    begin
        if(!rst)
        begin
            PCF <= '0;
        end
        else if(TrapIsSet)
        begin
            PCF <= CsrOutPC;           // Jump to trap vector / mepc
        end
        else if(PCSrcE)
        begin
            PCF <= PCBranchE;          // Taken branch/jump: never blocked by a fetch stall
        end
        else if(!StallF)
        begin
            PCF <= PCPlus4F;           // Next sequential instruction
        end
    end
endmodule