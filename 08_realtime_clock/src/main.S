/*
 * Test program to use an SSD1306 monochrome OLED screen.
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
    // rcc_apb1enr_base:      0x4002101C
    // rcc_cfgr3_base:        0x40021030
    // Note: many RTC registers are not cleared by a normal system
    //  reset, but an 'RTC domain reset' does occur on software and
    //  power resets. Still, we should reset any RTC registers we modify
    //  at the start of our program as a best practice.
    // Pre-init logic:
    // - Enable the LSI oscillator.
    // rcc_csr:                 0x40021024
    LDR  r0, =0x40021024
    LDR  r2, =0x00000001
    BL   read_mod_orr_write
    LDR  r2, =0x00000002
    rtc_wait_for_lsi_ready:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  rtc_wait_for_lsi_ready
    // - Enable Power controller clock in APB1
    //   rcc_apb1enr_base:     0x4002101C
    // PWREN is bit 28
    LDR  r0, =0x4002101C
    LDR  r2, =0x10000000
    BL   read_mod_orr_write
    // - Enable access to the Backup/RTC domain; enable DBP in PWR_CR.
    // pwr_base:                0x40007000
    // DBP is bit 8.
    LDR  r0, =0x40007000
    LDR  r2, =0x00000100
    BL   read_mod_orr_write
    // Perform backup domain reset.
    LDR  r0, =0x40021020
    LDR  r2, =0x00010000
    BL   read_mod_orr_write
    // Clear reset.
    LDR  r2, =0xFFFEFFFF
    BL   read_mod_and_write
    // Initialize the RTC (realtime clock) peripheral.
    // rcc_bdcr:                0x40021020
    // - Set RTC clock source.
    LDR  r0, =0x40021020
    LDR  r1, [r0]
    // Bits 8-9 in RCC_BDCR; LSI = 10, HSE/32 = 11, LSE = 01
    LDR  r2, =0xFFFFFCFF
    ANDS r1, r1, r2
    //LDR  r2, =0x00000100
    //LDR  r2, =0x00000300
    LDR  r2, =0x00008200
    ORRS r1, r1, r2
    STR  r1, [r0]
    // - Enable RTC clock; set bit 15 in RCC_BDCR.
    //LDR  r0, =0x40021020
    //LDR  r2, =0x00008000
    //BL   read_mod_orr_write
    // - Setup RTC synchronous subsecond prescaler.
    // -- Disable write protection (write 0xCA, 0x53 to RTC_WPR)
    // rtc_base:                0x40002800
    // rtc_wpr:                 0x40002824
    LDR  r0, =0x40002824
    LDR  r1, =0xCA
    STR  r1, [r0]
    LDR  r1, =0x53
    STR  r1, [r0]
    // -- Set initialization mode: set bit 7 in RTC_ISR
    // rtc_isr:                0x4000280C
    LDR  r0, =0x4000280C
    LDR  r2, =0x00000080
    // For whatever reason, the standard peripherals library sets a
    // full word's worth of '1's. So...okay...
    //LDR  r2, =0xFFFFFFFF
    BL   read_mod_orr_write
    // -- Wait for bit 6 to be set by hardware.
    LDR  r2, =0x00000040
    rtc_init_ready_wait:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  rtc_init_ready_wait
    // -- Set Asynchronous and synchronous prescaler values in RTC_PRER.
    //     This tells how quickly the 'subsecond' register should tick.
    //     So for 'random' number generation, faster is better.
    //     Let's just set them both to 0, with HSE/32 as the clock source.
    // rtc_prer:              0x40002810
    LDR  r0, =0x40002810
    // Async is bits 22-16
    // Sync is bits 14-0
    LDR  r2, =0xFF807FFF
    BL   read_mod_and_write
    // -- Reset bit 7 in RTC_ISR to un-enable init mode.
    LDR  r0, =0x4000280C
    LDR  r2, =0xFFFFFF7F
    BL   read_mod_and_write
    // -- Re-enable RTC write protection.
    LDR  r0, =0x40002824
    LDR  r1, =0x000000FF
    STR  r1, [r0]

    // Main loop; just load the RTC values into registers for observation
    // every handful of milliseconds.
    // (Load a register to show we reached the main loop.)
    LDR  r6, =0xF00D
    main_loop:
        MOVS r3, #50
        BL   delay_ms

        // Load RTC values.
        LDR  r0, =0x40002828
        LDR  r1, [r0]
        LDR  r2, =0x0000FFFF
        ANDS r1, r1, r2
        MOVS r5, r1

        // Loop back.
        B    main_loop
.size main, .-main
