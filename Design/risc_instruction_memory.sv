// =============================================================================
// risc_instruction_memory.sv
// -----------------------------------------------------------------------------
// Instruction memory (ROM) for RISC-V processor.
// =============================================================================
module risc_instruction_memory
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    input [ADDR_WIDTH-3:0] a1,
    output logic [DATA_WIDTH-1:0] RDdata
);
    localparam int DEPTH = 2**(ADDR_WIDTH-2);
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    integer idx;

    initial 
    begin
        for (idx = 0; idx < DEPTH; idx = idx + 1)
        begin
            mem[idx] = 32'h00000013;
        end
        $readmemb("C:/Ain_shams/RiscV/Python/binary1.txt",mem);
    end

    assign RDdata = mem[a1];

endmodule
