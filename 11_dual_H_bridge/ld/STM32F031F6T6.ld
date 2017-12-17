/* Entry Handler */
ENTRY( reset_handler )

/* End of RAM/Start of stack */
/* (4KB SRAM) */
_estack = 0x20001000;

/* Define minimum heap/stack sizes. */
/* 2KB Heap */
_Min_Heap_Size = 0x800;
/* 1KB Stack */
_Min_Stack_Size = 0x400;

MEMORY
{
    FLASH ( rx )      : ORIGIN = 0x08000000, LENGTH = 32K
    RAM ( rxw )       : ORIGIN = 0x20000000, LENGTH = 4K
    MEMORY_B1 ( rx )  : ORIGIN = 0x60000000, LENGTH = 0K
}

/* Define output sections */
SECTIONS
{
    /* Reset/ISR (Interrupt Service Routine) Handlers. */
    .isr_vector :
    {
        __isr_vector_start__ = .;
        /* Prevent GC from discarding. */
        KEEP(*(.isr_vector))
        ASSERT(. != __isr_vector_start__, "Empty .isr_vector");
    } >FLASH

    /* Text/code/ROData memory. */
    .text :
    {
        . = ALIGN(4);
        _stext = .;

        /* Code goes here: */
        *(.text*)
        /* RO Data goes here: */
        *(.rodata*)

        /* Don't discard static con/destructors. */
        KEEP(*(.init))
        KEEP(*(.fini))

        /* Mark end of text memory segment. */
        . = ALIGN(4);
        _etext = .;
    } >FLASH

    /* C++ Exception-handling memory. */
    .ARM.extab :
    {
        *(.ARM.extab*)
    } >FLASH
    .ARM.exidx :
    {
        *(.ARM.evidx*)
    } >FLASH

    /* According to Bjorn Forsman (thanks,) these are needed
       for Newlib and Eglibc - not sure if REALLY necessary. */
    .preinit_array :
    {
        PROVIDE_HIDDEN(__preinit_array_start = .);
        KEEP(*(.preinit_array*))
        PROVIDE_HIDDEN(__preinit_array_end = .);
    } >FLASH
    .init_array :
    {
        PROVIDE_HIDDEN(__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array*))
        PROVIDE_HIDDEN(__init_array_end = .);
    } >FLASH
    .fini_array :
    {
        PROVIDE_HIDDEN(__fini_array_start = .);
        KEEP(*(SORT(.fini_array.*)))
        KEEP(*(.fini_array*))
        PROVIDE_HIDDEN(__fini_array_end = .);
    } >FLASH

    /* Initialized data memory.
       Since this actually includes data, it technically goes
       into flash memory and is copied into RAM on init. */
    _sidata = .;
    .data : AT(_sidata)
    {
        /* Mark start of init-data memory. */
        . = ALIGN(4);
        _sdata = .;
        /* Initialized data goes here: */
        *(.data*)
        /* Mark end of init-data memory. */
        . = ALIGN(4);
        _edata = .;
    } >RAM

    /* BSS (Uninitialized data/zero-d) memory. */
    .bss :
    {
        /* Mark start of BSS memory. */
        . = ALIGN(4);
        _sbss = .;
        /* BSS 'data' goes here: */
        *(.bss*)
        *(COMMON)
        /* Mark end of BSS memory. */
        . = ALIGN(4);
        _ebss = .;
    } >RAM

    /* Reserve memory for the heap and stack. */
    ._heap :
    {
        . = ALIGN(4);
        _sheap = .;
        . = . + _Min_Heap_Size;
        . = ALIGN(4);
        _eheap = .;
    } >RAM
    ._stack :
    {
        . = ALIGN(4);
        . = . + _Min_Stack_Size;
        . = ALIGN(4);
    } >RAM
}

/* Extra values sometimes expected by .s assembly init code. */
__isr_vector_size__ = SIZEOF(.isr_vector);
__text_size__ = SIZEOF(.text);
__data_size__ = SIZEOF(.data);
__bss_size__ = SIZEOF(.bss);
