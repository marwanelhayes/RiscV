`define misa_mask   32'b0000_0000_1001_0101_0011_0001_1111_1111
`define mstatus_mask 32'b0000_0000_0000_0000_0000_0000_1000_1000
`define mcause_mask 32'b1000_0000_0000_0000_0000_1111_1111_1111
`define align_mask 32'b1111_1111_1111_1111_1111_1111_1111_1100
`define mtvec_mask 32'b1111_1111_1111_1111_1111_1111_1111_1101
`define mie_mask 32'b0000_0000_0000_0000_0000_1000_1000_1000
`define mpie_mask 32'b0000_0000_0000_0000_0000_1000_1000_1000
`define MIE 3     //Machine Interrupt Enable bit
`define MPIE 7    // Machine Interrupt Previous Enable bit
`define MPPS 11   // Machine Previous Privilege Start bit
`define MPPE 12   // Machine Previous Privilege End bit 
`define MT_I 7  // Machine Timer Interrupt Enable bit 
`define MS_I 3  // Machine Software Interrupt Enable bit
`define ME_I 11 // Machine External Interrupt Enable bit
`define IRQ (1 << `MT_I) | (1 << `MS_I) | (1 << `ME_I)
`define MTVEC_MODE_END 1
`define MTVEC_MODE_START 0
`define MTVEC_DIRECT 2'b00
`define MTVEC_VECTORED 2'b01
`define MACHINE_SOFTWARE_INTERRUPT_CAUSE 32'd3
`define MACHINE_TIMER_INTERRUPT_CAUSE 32'd7
`define MACHINE_EXTERNAL_INTERRUPT_CAUSE 32'd11
