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

// Global values.
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
  #include "../vector_tables/STM32F030F4T6_vt.S"
  #include "../boot/STM32F030F4T6_boot.S"
#elif  STM32F038F6
  #include "../vector_tables/STM32F038F6T6_vt.S"
  #include "../boot/STM32F038F6T6_boot.S"
#endif

/*
 * The Reset handler. Called on reset.
 */
.section .text.reset_handler
.weak reset_handler
.type reset_handler, %function
reset_handler:
    BL   boot_sequence

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
     * This time, our main method will actually do something.
     * We will enable the peripheral clock for the 'GPIOA' bank,
     * set a pin to push-pull output mode, and then cycle it
     * between 'low' and 'high' every 500ms (half-second).
     * Note that while your GPIO pin might be able to sink enough
     * current to light up an LED, it's safer to drive the gate
     * of something like an NPN transistor or N-channel MOSFET.
     *
     * Talking about 'enabling the GPIOA clock' might sound weird.
     * Here's the deal: to save power, these chips disable their
     * peripheral hardware features when they are not needed.
     * When they are needed, we turn them on by telling the chip
     * to send a clock signal to that peripheral. The peripheral
     * technically runs separately from the main program,
     * on its own clock signal. Remember when we set the
     * 'AHB' and 'APB' clocks to the system clock divided by 1?
     * Those are where these peripheral clocks come from.
     *
     * The GPIO configuration registers are listed in the chip's
     * reference manual, and are located at the base of the
     * 'AHB2PERIPH' memory region, +0x0400 for each bank.
     * So, GPIOA_Base is at 0x48000000, GPIOB is 0x48000400, etc.
     */
    // Step 1: Enable GPIOA clock. This is an RCC command;
    // in C-speak, 'RCC->AHBENR |= RCC_AHBPeriph_GPIOA'
    // rcc_[cr_]base:         0x40021000
    // rcc_ahbenr_base:       0x40021014 [bit 17 is GPIOA]
    // rcc_ahbrstr_base:      0x40021028 [bit 17 is GPIOA]
    // (But first, quickly reset it.)
    LDR  r0, =0x40021028
    LDR  r2, =0x00020000
    BL   read_mod_orr_write
    LDR  r2, =0xFFFDFFFF
    BL   read_mod_and_write
    LDR  r1, [r0]
    LDR  r0, =0x40021014
    LDR  r2, =0x00020000
    BL   read_mod_orr_write

    /*
     * Step 2: Configure GPIO pin:
     *  Bank:     GPIOA
     *  Pin #:    1         (= 0x0002)
     *  MODER:    GP Out    (= 0b01)
     *  OTYPER:   Push-pull (= 0b0)
     *  OSPEEDR:  Low-speed (= 0b00)
     *  PUPDR:    No pullx  (= 0b00)
     */
    // Set the mode to output.
    LDR  r0, =0x48000000
    LDR  r2, =0xFFFFFFF3
    BL   read_mod_and_write
    LDR  r2, =0x00000004
    BL   read_mod_orr_write
    // Set the output type to push-pull.
    LDR  r0, =0x48000004
    LDR  r2, =0xFFFFFFFD
    BL   read_mod_and_write
    // Set the speed to medium-speed.
    LDR  r0, =0x48000008
    LDR  r2, =0xFFFFFFF3
    BL   read_mod_and_write
    // Disable pull-up/down.
    LDR  r0, =0x4800000C
    BL   read_mod_and_write

    // (Infinite 'blink' loop)
    LDR  r3, =0x000001F4 // (500 ms delay value)
    // Use the ODR register to set/reset pin 1.
    LDR  r4, =0x48000014
    // 'Set' OR mask.
    LDR  r5, =0x00000002
    // 'Reset' AND mask.
    LDR  r6, =0xFFFFFFFD
    main_loop:
        // Turn the LED on, wait a bit.
        LDR  r7, [r4]
        ORRS r7, r7, r5
        STR  r7, [r4]
        BL   delay_ms
        // Turn the LED off, wait a bit.
        LDR  r7, [r4]
        ANDS r7, r7, r6
        STR  r7, [r4]
        BL   delay_ms
        // Loop back.
        B    main_loop
.size main, .-main
