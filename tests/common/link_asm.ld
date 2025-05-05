OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x00000080;
  .text.init : { *(.text.init) }

  /* .text : { *(.text) } */

  .text : {
        *(.text*.main);
        *(.text*);
  }

  .data : { *(.data) }
  .bss : { *(.bss) }
  _end = .;
}
