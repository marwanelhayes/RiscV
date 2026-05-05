// =============================================================================
// risc_instruction_memory.sv
// -----------------------------------------------------------------------------
// Instruction memory (ROM) for RISC-V processor.
//
// Responsibilities:
//   - Store instruction bytes in read-only memory
//   - Provide word-aligned instruction fetch interface
//   - Initialize from external binary file at simulation start
//
// Interface:
//   - Word-aligned address input (ADDR_WIDTH-2 bits)
//   - 32-bit instruction output
// =============================================================================
module risc_instruction_memory
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    // ─── Address input (word-aligned) ─────────────────────────────────────────
    input [ADDR_WIDTH-3:0] a1,

    // ─── Instruction output ─────────────────────────────────────────────────
    output logic [DATA_WIDTH-1:0] RDdata
);

    // ─── Internal registers – memory storage ────────────────────────────────
    localparam int DEPTH = 2**(ADDR_WIDTH-2);    // Number of instruction words
    logic [DATA_WIDTH-1:0] mem [DEPTH];         // Instruction memory array
    integer idx;                                  // Initialization index

    // ─── Memory initialization ───────────────────────────────────────────────
    initial 
    begin
        // Fill memory with default NOP instruction (ADDI x0, x0, 0)
        for (idx = 0; idx < DEPTH; idx = idx + 1)
        begin
            mem[idx] = 32'h00000013;
        end
        // Load program from external binary file
        $readmemb("C:/Ain_shams/RiscV/Python/binary1.txt",mem);
    end

    // ─── Combinational read ─────────────────────────────────────────────────
    assign RDdata = mem[a1];    // Read instruction at word-aligned address

endmodule
