// =============================================================================
// risc_reg_file.sv
// -----------------------------------------------------------------------------
// General Purpose Register (GPR) File for RISC-V processor.
//
// Responsibilities:
//   - Provide dual-ported read access (two simultaneous reads)
//   - Provide single-ported write access
//   - Store 32 integer registers (x0-x31)
//   - x0 is hardwired to zero
//
// Instantiates:
//   - risc_mem: the XLEN-wide register storage
// =============================================================================
import shared_pkg::*;

module risc_reg_file
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 5           // Register index width (32 registers)
) 
(
    // ─── Clock and reset ───────────────────────────────────────────────────────
    input clk,
    input rst,

    // ─── Read/Write interface ─────────────────────────────────────────────────
    input gpr_t Rs1,Rs2,Rd,            // Source and destination register indices
    input signed [DATA_WIDTH-1:0] WData,   // Write data
    input WE,                          // Write enable

    // ─── Read data outputs ───────────────────────────────────────────────────
    output logic signed [DATA_WIDTH-1:0] RD1,   // Read data port 1
    output logic signed [DATA_WIDTH-1:0] RD2    // Read data port 2
);
    // ─── risc_reg_file: one XLEN-wide storage array ─────────────────────────
    risc_mem  #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) M1 
    (
      .clk(clk),
      .rst(rst),
      .Rs1(Rs1),
      .Rs2(Rs2),
      .Rd(Rd),
      .WData(WData),
      .WE(WE),
      .RD1(RD1),
      .RD2(RD2)  
    );

endmodule