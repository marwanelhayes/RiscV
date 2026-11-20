/* =============================================================================
 * link.ld
 * -----------------------------------------------------------------------------
 * Link script for riscv-tests programs run on risc_top.
 *
 * The full-core bench has one 4 KiB RAM starting at address 0
 * (FINAL_ADDR_WIDTH = 12 in Design/shared_pkg.sv). Its layout is
 *   0x000 - 0xBFF : code (.text.init, .text)
 *   0xC00 - 0xFFF : tohost, data, bss
 * A program whose code or data does not fit fails to link and is skipped.
 * ===========================================================================*/
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x000;
  .text.init : { *(.text.init) }
  .text : { *(.text) }
  ASSERT(. <= 0xC00, "code does not fit below 0xC00")
  . = 0xC00;
  .tohost : { *(.tohost) }
  .data : { *(.data) *(.sdata) }
  .bss : { *(.bss) *(.sbss) }
  _end = .;
  ASSERT(_end <= 0x1000, "data does not fit in the 4 KiB data memory")
}
