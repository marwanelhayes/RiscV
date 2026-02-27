`define misa_mask 32'b0000_0000_1001_0101_0011_0001_1111_1111
`define mstatus_mask 32'b0000_0000_0000_0000_0000_0000_0000_1000
`define mcause_mask 32'b0000_0000_0000_0000_0000_1111_1111_1111
`define align_mask 32'b1111_1111_1111_1111_1111_1111_1111_1100
`define mie_mask 32'b0000_0000_0000_0000_0000_1000_1000_1000
`define mpie_mask 32'b0000_0000_0000_0000_0000_1000_1000_1000
`define MIE 3     //Machine Interrupt Enable bit
`define MPIE 7    // Machine Interrupt Previous Enable bit
`define MPPS 11   // Machine Previous Privilege Start bit
`define MPPE 12   // Machine Previous Privilege End bit 
`define MT_PIE 7  // Machine Timer Interrupt Enable bit 
`define MS_PIE 3  // Machine Software Interrupt Enable bit
`define ME_PIE 11 // Machine External Interrupt Enable bit    