/*
 * Test program to use a CAT24AA16 EEPROM chip over I2C.
 *
 * Copyright William Ransohoff, Vivonomicon, LLC, 2017
 *
 * Open source under the MIT License
 */

// The linker should set these, but you never know.
.syntax unified
#ifdef VVC_F0
    .cpu cortex-m0plus
#elif  VVC_F3
    .cpu cortex-m4
#endif
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
// Start/end of heap section
.word _sheap
.word _eheap

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
    // rcc_[cr_]base:         0x40021000
    // rcc_ahbenr_base:       0x40021014
    // rcc_ahbrstr_base:      0x40021028
    // Reset the GPIOA clock by setting/resetting the
    // IOPARST bit (#17) in RCC_AHBRSTR.
    LDR  r0, =0x40021028
    LDR  r2, =0x00020000
    BL   read_mod_orr_write
    LDR  r2, =0xFFFDFFFF
    BL   read_mod_and_write
    // Enable the GPIOA clock.
    LDR  r0, =0x40021014
    LDR  r2, =0x00020000
    BL   read_mod_orr_write

    // Setup the motor output pins; A0, A1, A2, and A3.
    LDR  r0, =0x48000000
    MOVS r3, #0
    LDR  r4, =0x00000001 // GPIO output mode
    LDR  r5, =0x00000000 // Push-pull
    LDR  r6, =0x00000000 // Low-speed
    LDR  r7, =0x00000000 // No pull-up/down.
    BL   init_gpio_pin
    MOVS r3, #1
    BL   init_gpio_pin
    MOVS r3, #2
    BL   init_gpio_pin
    MOVS r3, #3
    BL   init_gpio_pin

    // Setup the input button pins; A4, A5, A6, and A7.
    MOVS r3, #4
    LDR  r4, =0x00000000 // GPIO iput mode
    LDR  r5, =0x00000000 // (Not applicable for GP In)
    LDR  r6, =0x00000000 // (Not applicable for GP In)
    LDR  r7, =0x00000001 // Enable internal pullup.
    BL   init_gpio_pin
    MOVS r3, #5
    BL   init_gpio_pin
    MOVS r3, #6
    BL   init_gpio_pin
    MOVS r3, #7
    BL   init_gpio_pin

    // Main loop - just read the same byte from EEPROM.
    // (Mark end of execution.)
    LDR  r7, =0xF00D
    main_loop:
        // 50ms delay
        MOVS r3, #50
        BL   delay_ms

        // Check inputs.
        // Load GPIOA input register.
        LDR  r0, =0x48000010
        LDR  r1, [r0]
        // (0 means a button is pressed.)
        // r5 stores motor 1 direction; 0/1/2. r6 stores motor 2.
        MOVS r5, #0
        MOVS r6, #0
        // A4 = Motor 1 up.
        LDR  r2, =0x00000010
        ANDS r2, r2, r1
        BEQ  motor_1_up
        // A7 = Motor 1 down.
        LDR  r2, =0x00000080
        ANDS r2, r2, r1
        BEQ  motor_1_down
        B    motor_1_none
        motor_1_up:
            MOVS r5, #1
            B    motor_1_none
        motor_1_down:
            MOVS r5, #2
            B    motor_1_none
        motor_1_none:
        // A5 = Motor 2 up.
        LDR  r2, =0x00000020
        ANDS r2, r2, r1
        BEQ  motor_2_up
        // A6 = Motor 2 down.
        LDR  r2, =0x00000040
        ANDS r2, r2, r1
        BEQ  motor_2_down
        B    motor_2_none
        motor_2_up:
            MOVS r6, #1
            B    motor_2_none
        motor_2_down:
            MOVS r6, #2
            B    motor_2_none
        motor_2_none:

        // Set outputs appropriately.
        // A0 = 1A, A1 = 2A, A2 = 4A, A3 = 3A
        // Motor 1 = A0-1, motor 2 = A2-3
        // 0/0 if neither button pressed.
        // 1/0 if 'up'
        // 0/1 if 'down'
        // Load GPIOA output register
        LDR  r0, =0x48000014
        LDR  r1, [r0]
        LDR  r2, =0xFFFFFFF0
        ANDS r1, r1, r2
        MOVS r2, r6
        LSLS r2, r2, #2
        ORRS r2, r2, r5
        ORRS r1, r1, r2
        STR  r1, [r0]

        // Loop back.
        B    main_loop
.size main, .-main
