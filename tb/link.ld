ENTRY(_start)
MEMORY
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw) : ORIGIN = 0x<TRUE_BASE>, LENGTH = 1K
}
SECTIONS
{
    .text   : { *(.text.start) *(.text*) *(.rodata*) } > IMEM
    /DISCARD/ : { *(.comment) *(.eh_frame) *(.data*) *(.bss*) }
}
