#ifndef _VVC_BOOT_SEQ
#define _VVC_BOOT_SEQ

.syntax unified
.cpu cortex-m0plus
.fpu softvfp
.thumb

.section .text.boot_sequence,"ax",%progbits
boot_sequence:
    // Set the stack pointer to the end of the stack.
    // See the linker scripts in 'ld/' for these defs.
    LDR  r0, =_estack
    MOV  sp, r0
    // Push the Link Register for returning later.
    PUSH { lr }

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
        B    reset_chip_state

    reset_chip_state:
        // Bring the chip to a known healthy state by
        // resetting/defaulting some registers.
        // Clock registers:
        // rcc_cr_base:           .word 0x40021000
        // rcc_cfgr_base:         .word 0x40021004
        // rcc_cir_base:          .word 0x40021008
        // rcc_cfgr2_base:        .word 0x4002102C
        // rcc_cfgr3_base:        .word 0x40021030
        // rcc_cr2_base:          .word 0x40021034
        // Enable the HSION bit
        //LDR  r0, =0x40021000 (TODO Delete)
        //LDR  r1, =0x40021004
        LDR  r0, =0x40021000
        LDR  r2, =0x00000001
        BL   read_mod_orr_write
        // Reset CFGR register. (Default 0x08FFB80C)
        LDR  r0, =0x40021004
        LDR  r2, =0x08FFB80C
        BL   read_mod_and_write
        // Reset CR register's HSEON, CSSON, and PLLON bits.
        LDR  r0, =0x40021000
        LDR  r2, =0xFEF6FFFF
        BL   read_mod_and_write
        // Reset CR register's HSEBYP bit.
        LDR  r2, =0xFFFBFFFF
        BL   read_mod_and_write
        // Reset CFGR register's PLLSRC, PLLXTRPRE,
        // PLLMUL, and USBPRE bits.
        LDR  r0, =0x40021004
        LDR  r2, =0xFFC0FFFF
        BL   read_mod_and_write
        // Reset CFGR2's PREDIV1 bits.
        LDR  r0, =0x4002102C
        LDR  r2, =0xFFFFFFF0
        BL   read_mod_and_write
        // Reset CFGR3's USARTSW, I2CSW, CECSW, and ADCSW bits.
        LDR  r0, =0x40021030
        LDR  r2, =0xFFFFFEAC
        BL   read_mod_and_write
        // Reset CR2's HSI14 bit.
        LDR  r0, =0x40021034
        LDR  r2, =0xFFFFFFFE
        BL   read_mod_and_write
        // Disable all RCC interrupts in CIR.
        LDR  r0, =0x40021008
        LDR  r2, =0x00000000
        STR  r2, [r0]

        /*
         * Setup and enable the system clock to use HSE osc.
         */
        // Set CR's HSEON bit.
        LDR  r0, =0x40021000
        LDR  r2, =0x00010000
        BL   read_mod_orr_write
        // Wait for the HSE to be ready.
        LDR  r2, =0x00020000
        hse_osc_stable_wait_loop:
            LDR  r3, [r0]
            ANDS r3, r3, r2
            CMP  r3, r2
            BEQ  hse_osc_stable_done
            B    hse_osc_stable_wait_loop
        hse_osc_stable_done:
        // Reset/set the Flash ACR to enable prefetching and
        // use a 1-wait state.
        LDR  r0, =0x40022000
        LDR  r2, =0xFFFFFFE8
        BL   read_mod_and_write
        LDR  r2, =0x00000011
        BL   read_mod_orr_write
        // Set HCLK and PCLK prescalars to divide SYSCLK by 1, in
        // the RCC_CFGR register.
        LDR  r0, =0x40021004
        LDR  r2, =0x00000000
        BL   read_mod_orr_write
        // Also in the CFGR register, configure the PLL.
        // Reset/set the PLLSRC, PLLXTPRE, and 4x PLLMULL bits.
        // Use PLLMULL of 6, for 8MHz*6=48MHz.
        LDR  r2, =0xFFC0FFFF
        BL   read_mod_and_write
        LDR  r2, =0x00110000
        BL   read_mod_orr_write

        /*
         * Enable the PLL in the RCC_CR register, then loop until
         * the PLLRDY bit is set. Similar to how we turned on the
         * HSE oscillator.
         */
        LDR  r0, =0x40021000
        LDR  r2, =0x01000000
        BL   read_mod_orr_write
        // Loop until PLL is ready.
        LDR  r2, =0x02000000
        pll_ready_loop:
            LDR  r1, [r0]
            ANDS r1, r1, r2
            CMP  r1, r2
            BEQ  pll_ready_done
            B    pll_ready_loop

        pll_ready_done:
        /*
         * Now that the PLL is ready, we can select it as the
         * system clock source, SYSCLK. (In RCC_CFGR)
         */
        LDR  r0, =0x40021004
        LDR  r2, =0xFFFFFFFC
        BL   read_mod_and_write
        LDR  r2, =0x00000002
        BL   read_mod_orr_write
        // Loop until PLL is system clock source.
        LDR  r2, =0x00000008
        LDR  r3, =0x0000000C
        pll_is_sys_clock_loop:
            LDR  r1, [r0]
            ANDS r1, r1, r3
            CMP  r1, r2
            BEQ  pll_is_sys_clock_done
            B    pll_is_sys_clock_loop

        pll_is_sys_clock_done:
        /* 48MHz PLL is now the system clock source. */
        // We PUSH'd the Link Register at the beginning of this
        // assembly function; now POP it into the Program Counter.
        POP  { pc }
.size boot_sequence, .-boot_sequence

#endif
