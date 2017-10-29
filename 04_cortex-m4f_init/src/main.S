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

#ifdef STM32F303K8
  #include "../vector_tables/STM32F303K8T6_vt.S"
  #include "../boot/STM32F303K8T6_boot.S"
#elif  STM32F303CC
  #include "../vector_tables/STM32F303CCT6_vt.S"
  #include "../boot/STM32F303CCT6_boot.S"
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
    // Infinite 'set/increment' loop to signal that we have
    // reached the end of the program.
    LDR  r1, 0xF00D
    MOVS r0, #0
    main_loop:
        ADDS r0, r0, #1
        B    main_loop
.size main, .-main
