// =============================================================================
// memory_stage.sv
// -----------------------------------------------------------------------------
// Memory stage of the RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Access data memory for load and store operations
//   - Pass through control signals and data to write-back stage
//   - Handle memory byte/halfword/word selection via funct3
//
// Instantiates:
//   - risc_data_memory: data memory for loads/stores
// =============================================================================
import shared_pkg::*;

module memory_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ── MEM/WB register inputs ────────────────────────────────────────────────
    input signed [DATA_WIDTH-1:0] ALUOutM,          // Address computed by ALU
    input signed [DATA_WIDTH-1:0] WriteDataM,       // Data to store
    input [ADDR_WIDTH-1:0] PCPlus4M,                // PC+4 from execute
    input gpr_t RdM,                                // Destination register
    input logic [2:0] funct3M,                      // Load/store size select
    input RegWriteM,                               // Register write enable
    input logic [DATA_WIDTH-1:0] CsrOutM,          // CSR read data
    input selector_t SelectorM,                    // Write-back data select
    input MemWriteM,                               // Memory write enable

    // ── FPU inputs from execute stage ─────────────────────────────────────────
    input fpr_t RdFM,                               // FPR destination
    input logic OverflowM,                         // FPU overflow flag
    input logic UnderflowM,                        // FPU underflow flag
    input logic NaNM,                              // FPU NaN flag
    input logic InfM,                              // FPU infinity flag
    input logic ZeroM,                             // FPU zero flag
    input logic InvalidDivM,                       // Invalid division flag
    input logic [DATA_WIDTH-1:0] FPUOutM,          // FPU result
    input move_operation_t MoveOperationM,         // FPU move operation
    input FPURegWriteM,                             // FPR write enable

    // ── Outputs to write-back stage ───────────────────────────────────────────
    output logic signed [DATA_WIDTH-1:0] ReadDataW,    // Loaded data
    output gpr_t RdW,                                   // Destination register
    output logic RegWriteW,                             // Register write enable
    output selector_t SelectorW,                        // Write-back select
    output logic [ADDR_WIDTH-1:0] PCPlus4W,             // PC+4 to WB
    output logic [DATA_WIDTH-1:0] CsrOutW,             // CSR data to WB
    output logic signed [DATA_WIDTH-1:0] ALUOutW,     // ALU result to WB

    // ── FPU outputs to write-back stage ───────────────────────────────────────
    output fpr_t RdFW,                                  // FPR destination
    output logic OverflowW,                            // FPU overflow flag
    output logic UnderflowW,                            // FPU underflow flag
    output logic NaNW,                                 // FPU NaN flag
    output logic InfW,                                 // FPU infinity flag
    output logic ZeroW,                                // FPU zero flag
    output logic InvalidDivW,                           // Invalid division flag
    output logic [DATA_WIDTH-1:0] FPUOutW,            // FPU result
    output move_operation_t MoveOperationW,            // FPU move operation
    output logic FPURegWriteW                           // FPR write enable
);

    // ─── Internal wires – data memory interface ──────────────────────────────
    logic [DATA_WIDTH-1:0] ReadDataM;    // Data returned from memory

    // ─── memory_stage: data memory ───────────────────────────────────────────
    risc_data_memory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) M1 
    (
        .clk(clk),
        .rst(rst),
        .a1(ALUOutM[ADDR_WIDTH-1:0]),       // Word-aligned address
        .Wdata(WriteDataM),                 // Data to write
        .we(MemWriteM),                     // Write enable
        .sel(load_store_t'(funct3M)),       // Byte/half/word select
        .RDdata(ReadDataM)                  // Read data output
    );

    // ─── MEM/WB pipeline register ─────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            ReadDataW <= '0;
            RegWriteW <= 1'b0;
            SelectorW <= ALUToReg;
            RdW <= zero;
            ALUOutW <= '0;
            PCPlus4W <= '0;
            CsrOutW <= '0;
            RdFW <= f0;
            OverflowW <= 1'b0;
            UnderflowW <= 1'b0;
            NaNW <= 1'b0;
            InfW <= 1'b0;
            ZeroW <= 1'b0;
            InvalidDivW <= 1'b0;
            FPUOutW <= '0;
            MoveOperationW <= FPUToFPU;
            FPURegWriteW <= 1'b0;
        end
        else
        begin
            ReadDataW <= ReadDataM;
            RegWriteW <= RegWriteM;
            SelectorW <= SelectorM;
            RdW <= RdM;
            PCPlus4W <= PCPlus4M;
            ALUOutW <= ALUOutM;
            CsrOutW <= CsrOutM;
            RdFW <= RdFM;
            OverflowW <= OverflowM;
            UnderflowW <= UnderflowM;
            NaNW <= NaNM;
            InfW <= InfM;
            ZeroW <= ZeroM;
            InvalidDivW <= InvalidDivM;
            FPUOutW <= FPUOutM;
            MoveOperationW <= MoveOperationM;
            FPURegWriteW <= FPURegWriteM;
        end
    end
    
endmodule