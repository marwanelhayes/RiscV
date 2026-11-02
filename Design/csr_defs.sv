// =============================================================================
// csr_defs.sv
// -----------------------------------------------------------------------------
// CSR bit positions and interrupt-related constants for RISC-V (M-mode).
//
// Responsibilities:
//   - Define bit positions inside mstatus, mie/mip and mtvec
//   - Define interrupt cause values for timer, software, and external interrupts
//   - Define MTVEC mode encodings (direct vs vectored)
//
// Only positions and small values live here. Masks depend on XLEN, so they
// are built from these positions inside the modules that use them.
// =============================================================================

// MSTATUS bit positions
`define MIE 3     // Machine Interrupt Enable bit
`define MPIE 7    // Machine Interrupt Previous Enable bit
`define MPPS 11   // Machine Previous Privilege Start bit
`define MPPE 12   // Machine Previous Privilege End bit
`define FSS 13    // Floating-point Status Start bit
`define FSE 14    // Floating-point Status End bit

// Interrupt enable / pending bit positions in mie and mip
`define MT_I 7  // Machine Timer Interrupt bit
`define MS_I 3  // Machine Software Interrupt bit
`define ME_I 11 // Machine External Interrupt bit

// MTVEC mode range
`define MTVEC_MODE_END 1
`define MTVEC_MODE_START 0

// MTVEC mode encoding
`define MTVEC_DIRECT 2'b00
`define MTVEC_VECTORED 2'b01

// Machine interrupt cause values (mcause without the interrupt bit)
`define MACHINE_SOFTWARE_INTERRUPT_CAUSE 3
`define MACHINE_TIMER_INTERRUPT_CAUSE 7
`define MACHINE_EXTERNAL_INTERRUPT_CAUSE 11

// misa extension bits
`define MISA_F 5
`define MISA_I 8
`define MISA_M 12
