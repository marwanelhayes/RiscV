// =============================================================================
// data_memory.sv
// -----------------------------------------------------------------------------
// Synchronous data memory (RAM) for RISC-V processor.
//
// Responsibilities:
//   - Word-level synchronous read/write memory
//   - Provide combinational read for low-latency loads
//   - Synchronous write on positive clock edge
//   - Asynchronous reset to zero
// =============================================================================
module data_memory
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
) 
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ─── Memory interface ─────────────────────────────────────────────────────
    input [ADDR_WIDTH-1:0] a1,                  // Memory address
    input signed [DATA_WIDTH-1:0] Wdata,        // Write data
    input we,                                     // Write enable

    // ─── Read data output ────────────────────────────────────────────────────
    output logic signed [DATA_WIDTH-1:0] RDdata
);
    // ─── Internal parameters ─────────────────────────────────────────────────
    localparam DEPTH = 2**ADDR_WIDTH;
    
    // ─── Internal registers – memory storage ────────────────────────────────
    logic [DATA_WIDTH-1:0] mem [DEPTH];    // Memory array

    // ─── Combinational read (for low-latency) ────────────────────────────────
    assign RDdata = mem[a1];

    // ─── Synchronous write ───────────────────────────────────────────────────
    always_ff @(negedge clk or negedge rst) 
    begin
        if (!rst) 
        begin
            foreach(mem[i])
                mem[i] <= '0;    // Initialize memory to zero
        end
        else 
        begin
            if(we)
            begin
                mem[a1] <= Wdata;    // Write data to memory
            end
        end
    end
endmodule
