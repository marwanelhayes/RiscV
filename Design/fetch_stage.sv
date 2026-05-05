// =============================================================================
// fetch_stage.sv
// -----------------------------------------------------------------------------
// Instruction Fetch stage of the RISC-V 5-stage pipeline.
//
// Responsibilities:
//   - Fetch instructions from instruction memory using PC
//   - Compute next sequential PC (PC + 4)
//   - Handle pipeline stalls and flushes from hazard unit
//   - Output instruction and PC to decode stage
//
// Instantiates:
//   - pc_adder: calculates PC+4
//   - risc_instruction_memory: instruction ROM
// =============================================================================
module fetch_stage
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)
(
    // ── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ── Program counter from previous stage ──────────────────────────────────
    input [ADDR_WIDTH-1:0] PCF,

    // ── Pipeline control from hazard unit ────────────────────────────────────
    input StallD,      // Stall the pipeline (hold current state)
    input FlushD,      // Flush the pipeline (inject NOP)

    // ── Outputs to decode stage ──────────────────────────────────────────────
    output logic [ADDR_WIDTH-1:0] PCPlus4D,      // PC+4 for current instruction
    output logic [DATA_WIDTH-1:0] InstructionD,  // Fetched instruction

    // ── Outputs to previous stage ────────────────────────────────────────────
    output wire [ADDR_WIDTH-1:0] PCPlus4F        // PC+4 for next fetch address
);

    // ─── Internal wires – instruction fetch ───────────────────────────────────
    logic [DATA_WIDTH-1:0] InstructionF;  // Instruction from memory (combinational)

    // ─── fetch_stage: PC+4 calculation ───────────────────────────────────────
    pc_adder #(.ADDR_WIDTH(ADDR_WIDTH)) P1 
    (
        .PC(PCF),
        .PCPlus4(PCPlus4F)
    );

    // ─── fetch_stage: instruction memory ───────────────────────────────────────
    risc_instruction_memory #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) IM1 
    (
        .a1(PCF[ADDR_WIDTH-1:2]),    // Word-aligned address
        .RDdata(InstructionF)
    );

    // ─── IF/ID pipeline register ─────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            PCPlus4D <= '0;
            InstructionD <= 32'h00_00_00_33;    // NOP instruction (ADDI x0, x0, 0)
        end
        else if(FlushD)
        begin
            PCPlus4D <= '0;
            InstructionD <= 32'h00_00_00_33;    // Flush with NOP
        end
        else if(!StallD)
        begin
            PCPlus4D <= PCPlus4F;                // Latch PC+4 on valid cycle
            InstructionD <= InstructionF;        // Latch fetched instruction
        end
    end

endmodule