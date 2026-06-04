ENTRY(_start)

SECTIONS
{

    . = 0x00100000; 

    .text : AT(ADDR(.text))
    {
        *(.text)
    }

    .data : AT(ADDR(.data))
    {
        *(.data)
    }

    .rodata : AT(ADDR(.rodata))
    {
        *(.rodata)
    }

    .bss : AT(ADDR(.bss))
    {
        *(.bss)
    }
}