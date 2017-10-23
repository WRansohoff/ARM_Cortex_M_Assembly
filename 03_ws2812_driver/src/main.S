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
    // Reset, then enable the GPIOA clock.
    // rcc_[cr_]base:         0x40021000
    // rcc_ahbenr_base:       0x40021014 [bit 17 is GPIOA]
    // rcc_ahbrstr_base:      0x40021028 [bit 17 is GPIOA]
    LDR  r0, =0x40021028
    LDR  r2, =0x00020000
    BL   read_mod_orr_write
    LDR  r2, =0xFFFDFFFF
    BL   read_mod_and_write
    LDR  r1, [r0]
    LDR  r0, =0x40021014
    LDR  r2, =0x00020000
    BL   read_mod_orr_write

    // Configure GPIO pin:
    //  Bank:     GPIOA
    //  Pin #:    1         (= 0x0002)
    //  MODER:    GP Out    (= 0b01)
    //  OTYPER:   Push-pull (= 0b0)
    //  OSPEEDR:  Low-speed (= 0b00)
    //  PUPDR:    No pullx  (= 0b00)
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
    // Set the speed to low-speed.
    LDR  r0, =0x48000008
    LDR  r2, =0xFFFFFFF3
    BL   read_mod_and_write
    // Disable pull-up/down.
    LDR  r0, =0x4800000C
    BL   read_mod_and_write

    // Infinite 'blink' loop for the WS2812; cycle between
    // green, red, and blue every half-second.
    // TODO: Write convenience functions for sending colors.
    // TODO: Chain multiple LEDs together.
    main_loop:
        LDR  r0, =0x48000014
        LDR  r1, =0x00000002
        // Write 'Green.'
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_latch
        // Delay 500ms.
        LDR  r3, =0x000001F4 // (500 ms delay value)
        BL   delay_ms
        // Write 'Blue.'
        LDR  r0, =0x48000014
        LDR  r1, =0x00000002
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_latch
        // Delay 500ms.
        LDR  r3, =0x000001F4 // (500 ms delay value)
        BL   delay_ms
        LDR  r0, =0x48000014
        LDR  r1, =0x00000002
        // Write 'Red.'
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_1
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_write_0
        BL   ws2812_latch
        // Delay 500ms.
        LDR  r3, =0x000001F4 // (500 ms delay value)
        BL   delay_ms
        B    main_loop
.size main, .-main
