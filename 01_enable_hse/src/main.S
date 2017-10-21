/*
 * Test program to turn on the HSE oscillator.
 *
 * Uses a full vector table/etc initialization and startup.
 * Built from a combination of ST's example startup files,
 * poring over datasheets/references, and google/blog posts.
 *
 * But it should be easy to adapt to any manufacturer; a lot
 * of this is common to Cortex-M processors, nevermind Cortex-M0.
 * You'd just need to adjust the code surrounding peripherals;
 * that'll be in the datasheets, and you can verify your
 * addresses/values in peripheral library files if the vendor
 * provides them.
 *
 * Copyright William Ransohoff, Vivonomicon, LLC, 2017
 *
 * Open source under the MIT License
 */

// The linker should set these, but you never know.
.syntax unified
.cpu cortex-m0plus
.fpu softvfp
.thumb

// Global values to export.
.global reset_handler
.global main

/*
 * Addresses defined in linker script; see files
 * in 'ld/' for definitions of these values, which
 * depend on the specific chip.
 */
// Start of initialization values for the .data section.
.word _sidata
// Start / end of .data section.
.word _sdata
.word _edata
// Start / end of .bss section.
.word _sbss
.word _ebss

#ifdef STM32F030F4
  #include "../vector_tables/STM32F030F4T6.S"
#elif  STM32F038F6
  #include "../vector_tables/STM32F038F6T6.S"
#endif

/*
 * The Reset handler. Called on reset.
 */
.section .text.reset_handler
.weak reset_handler
.type reset_handler, %function
reset_handler:
    // Set the stack pointer to the end of the stack.
    // See the linker scripts in 'ld/' for these defs.
    LDR  r0, =_estack
    MOV  sp, r0

    // Copy data from flash to RAM data init section.
    // R2 will store our progress along the sidata section.
    MOVS r0, #0
    // Load the start/end addresses of the data section,
    // and the start of the data init section.
    LDR  r1, =_sdata
    LDR  r2, =_edata
    LDR  r3, =_sidata
    B    copy_sidata_loop

    copy_sidata:
        // Offset the data init section by our copy progress.
        LDR  r4, [r3, r0]
        // Copy the current word into data, and increment.
        STR  r4, [r1, r0]
        ADDS r0, r0, #4

    copy_sidata_loop:
        // Unless we've copied the whole data section, copy the
        // next word from sidata->data.
        ADDS r4, r0, r1
        CMP  r4, r2
        BCC  copy_sidata

        // Once we are done copying the data section into RAM,
        // move on to filling the BSS section with 0s.
        MOVS r0, #0
        LDR  r1, =_sbss
        LDR  r2, =_ebss
        B    reset_bss_loop

    // Zero out the BSS segment.
    reset_bss:
        // Store a 0 and increment by a word.
        STR  r0, [r1]
        ADDS r1, r1, #4

    reset_bss_loop:
        // We'll use R1 to count progress here; if we aren't
        // done, reset the next word and increment.
        CMP  r1, r2
        BCC  reset_bss

    // Branch to the main program.
    B    main
.size reset_handler, .-reset_handler

/*
 * A 'main' method to branch to after initialization stuff is
 * completed by the Reset handler. This is the core program.
 */
.section .text.main
.weak main
.type main, %function
main:
    /*
     * Step 1: Reset to default state.
     * I checked my vendor's 'system_stm32f...' file
     * for a canonical 'reset state' - you can probably do
     * the same for other chips. This example is for STM32F030s
     */
    // rcc_cr_base:           .word 0x40021000
    // rcc_cfgr_base:         .word 0x40021004
    // rcc_cir_base:          .word 0x40021008
    // rcc_cfgr2_base:        .word 0x4002102C
    // rcc_cfgr3_base:        .word 0x40021030
    // Enable the HSION bit
    LDR  r0, =0x40021000
    LDR  r1, =0x40021004
    LDR  r2, =0x00000001
    LDR  r3, [r0]
    ORRS r3, r3, r2
    STR  r3, [r0]
    // Reset CFGR register. (Default 0x08FFB80C)
    LDR  r2, =0x08FFB80C
    LDR  r3, [r1]
    ANDS r3, r3, r2
    STR  r3, [r1]
    // Reset CR register's HSEON, CSSON, and PLLON bits.
    LDR  r2, =0xFEF6FFFF
    LDR  r3, [r0]
    ANDS r3, r3, r2
    STR  r3, [r0]
    // Reset CR register's HSEBYP bit.
    LDR  r2, =0xFFFBFFFF
    LDR  r3, [r0]
    ANDS r3, r3, r2
    STR  r3, [r0]
    // Reset CFGR register's PLLSRC, PLLXTRPRE,
    // PLLMUL, and USBPRE bits.
    LDR  r2, =0xFFC0FFFF
    LDR  r3, [r1]
    ANDS r3, r3, r2
    STR  r3, [r1]
    // Reset CFGR2's PREDIV1 bits.
    LDR  r4, =0x4002102C
    LDR  r2, =0xFFFFFFF0
    LDR  r3, [r4]
    ANDS r3, r3, r2
    STR  r3, [r4]
    // Reset CFGR3's USARTSW, I2CSW, CECSW, and ADCSW bits.
    LDR  r4, =0x40021030
    LDR  r2, =0xFFFFFEAC
    LDR  r3, [r4]
    ANDS r3, r3, r2
    STR  r3, [r4]
    // Reset CR2's HSI14 bit.
    LDR  r4, =0x40021034
    LDR  r2, =0xFFFFFFFE
    LDR  r3, [r4]
    ANDS r3, r3, r2
    STR  r3, [r4]
    // Disable all RCC interrupts in CIR.
    LDR  r4, =0x40021008
    LDR  r2, =0x00000000
    STR  r2, [r4]

    /*
     * Setup and enable the system clock to use HSE osc.
     */
    // Set CR's HSEON bit.
    LDR  r3, [r0]
    LDR  r2, =0x00010000
    ORRS r3, r3, r2
    STR  r3, [r0]

    // Wait for the HSE to be ready.
    LDR  r2, =0x00020000
    hse_osc_stable_wait_loop:
        LDR  r3, [r0]
        ANDS r3, r3, r2
        CMP  r3, r2
        BEQ  hse_osc_stable_done
        B    hse_osc_stable_wait_loop

    hse_osc_stable_done:
    /*
     * With a good high-speed signal ready, configure the flash
     * prefetch buffer in preparation for increasing the system
     * clock frequency. I guess this is the hardware that
     * retrieves your program from flash memory and stuff.
     *
     * 0x40000000 is the base location of 'peripheral' options
     * in memory - hardware features that you can access by
     * read/writing specific bits of memory.
     * 0x00020000 is the offset for peripherals located in the
     * 'AHB' peripherals region, and then the flash options are 
     * further offset by 0x00002000. The ACR register is the
     * first byte in those options, at offset 0.
     * We want to set the ACR register's PRFTBE bit to ensure
     * that the prefetch buffer is enabled, and set the 3
     * 'latency' bits to '001' to indicate that our SYSCLK
     * (system clock) will be between 24MHz and 48MHz.
     * This means setting the register to 0x00000011
     *
     * This information about what bits do what in the registers
     * is at the end of the 'Flash' chapter in the reference
     * manual for my chip; 'reference manuals' go into programming
     * details than 'datasheets', which tend to focus on stuff
     * that is relevant to hardware and system designers.
     * The C equivalent from a template startup file is:
     * 'FLASH->ACR = FLASH_ACR_PRFTBE | FLASH_ACR_LATENCY;'
     * I'm doing an |= instead though, because the manual says
     * to leave 'reserved' bits alone and the Flash ACR register
     * is like 75% reserved bits. Who knows if that matters, tho.
     */
    LDR  r4, =0x40022000
    LDR  r2, =0x00000011
    LDR  r3, [r4]
    ORRS r3, r3, r2
    STR  r3, [r4]

    /*
     * Right. Now on to the actual system clock configuration.
     *
     * First, we set a couple of clocks to use the SYSCLK
     * core system clock as their source; HCLK and PCLK.
     * HCLK is the AHB clock; for simplicity, set it to SYSCLK/1.
     * PCLK is the APB clock; again, set to SYSCLK/1.
     * I think they're just different 'regions' of peripheral
     * hardware, maybe because 32 bits is too small for a robust
     * range of hardware modules to all have their own options
     * in a single domain? I dunno.
     *
     * After that, we configure the Phase-Locked Loop, which I
     * think is some ... thing ... that splits the HSE signal
     * into a higher frequency. We will use it to turn 8MHz
     * into 48MHz. In the RCC_CFGR register, we set PLLSRC to
     * say that we want to use the HSE signal / a chosen factor,
     * instead of the HSI signal / 2. We do not set PLLXTPRE,
     * which would pre-divide our signal by 2; there are actually
     * 4 bits for choosing that factor in CFGR2, and PLLXTPRE
     * is a copy of the 0th. Finally, we set PLLMULL to 6, because
     * our oscillator is 8MHz and we want a 48MHz clock signal.
     * This works out to CFGR |= 0x00110000, after resetting
     * the bits with CFGR &= 0xFFC0FFFF
     */
    // Set HCLK and PCLK prescalars to divide SYSCLK by 1, in
    // the RCC_CFGR register. This is literally 'X |= 0', but
    // this is a full startup process and sometimes you'll want
    // peripherals to run faster than the core clock; again,
    // slower clock cycles save power. They're bits 4-7H, 8-10P.
    LDR  r2, =0x00000000
    LDR  r3, [r1]
    ORRS r3, r3, r2
    // Also in the CFGR register, configure the PLL.
    // First, clear the PLLSRC, PLLXTPRE, and 4x PLLMULL bits.
    LDR  r2, =0xFFC0FFFF
    ANDS r3, r3, r2
    // Then, set them appropriately.
    LDR  r2, =0x00110000
    ORRS r3, r3, r2
    STR  r3, [r1]

    /*
     * Enable the PLL in the RCC_CR register, then loop until
     * the PLLRDY bit is set. Similar to how we turned on the
     * HSE oscillator.
     */
    LDR  r2, =0x01000000
    LDR  r3, [r0]
    ORRS r3, r3, r2
    STR  r3, [r0]
    // Loop until PLL is ready.
    LDR  r2, =0x02000000
    pll_ready_loop:
        LDR  r3, [r0]
        ANDS r3, r3, r2
        CMP  r3, r2
        BEQ  pll_ready_done
        B    pll_ready_loop

    pll_ready_done:
    /*
     * Now that the PLL is ready, we can select it as the system
     * clock source, SYSCLK. This is done with the 'SW' bits in
     * the RCC_CFGR register, and verified through the 'SWS' bits.
     * In both cases, '10' indicates the PLL.
     */
    LDR  r2, =0xFFFFFFFC
    LDR  r3, [r1]
    ANDS r3, r3, r2
    LDR  r2, =0x00000002
    ORRS r3, r3, r2
    STR  r3, [r1]
    // Loop until PLL is system clock source.
    LDR  r2, =0x00000008
    LDR  r4, =0x0000000C
    pll_is_sys_clock_loop:
        LDR  r3, [r1]
        ANDS r3, r3, r4
        CMP  r3, r2
        BEQ  pll_is_sys_clock_done
        B    pll_is_sys_clock_loop

    pll_is_sys_clock_done:
    /*
     * The PLL is now the system clock, and we should be running
     * our code at a core clock frequency of 48MHz! Further, the
     * AHB and APB domains should be ready to have their
     * peripheral clocks enabled for things like GPIO.
     * So, on to the main program:
     */
    MOVS r0, #0
    main_loop:
        ADDS r0, r0, #1
        B    main_loop
.size main, .-main
