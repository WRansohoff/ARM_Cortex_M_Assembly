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

    // Configure, then reset/enable the I2C1 clock.
    // rcc_apb1rstr_base:     0x40021010
    // rcc_apb1enr_base:      0x4002101C
    //   (I2C1[RST/ENR] = bit 21 for 2x^)
    // rcc_cfgr3_base:        0x40021030
    //   (I2C1SW = bit 4, 0=HSI / 1=SYSCLK)
    // Set/reset the I2C1 clock reset bit.
    LDR  r0, =0x40021010
    LDR  r2, =0x00200000
    BL   read_mod_orr_write
    LDR  r2, =0xFFDFFFFF
    BL   read_mod_and_write
    // Set the I2C1 clock source
    LDR  r0, =0x40021030
    LDR  r2, =0x00000010
    BL  read_mod_orr_write
    // Enable the I2C1 clock.
    LDR  r0, =0x4002101C
    LDR  r2, =0x00200000
    BL   read_mod_orr_write

    // Clear/set Alternate Function modes on I2C pins.
    // gpioa_afrh_base:       0x48000024
    // (A9 = SCL | A10 = SDA | GPIO AF 4)
    // (A9 = AFRH[7:4] = 0100 | A10 = AFRH[11:8] = 0100)
    LDR  r0, =0x48000024
    LDR  r2, =0xFFFFF00F
    BL   read_mod_and_write
    LDR  r2, =0x00000440
    BL   read_mod_orr_write
    // Set basic GPIO pin settings
    // Use util helper, but both SCL/SDA are:
    // gpioa_[moder_]base:    0x48000000  [AF   =  0b10]
    // gpioa_otyper_base:     0x48000004  [OD   =  0b 1]
    // gpioa_ospeedr_base:    0x48000008  [Low  =  0b00]
    // gpioa_pupdr_base:      0x4800000C  [None =  0b00]
    LDR  r0, =0x48000000
    MOVS r3, #9
    LDR  r4, =0x00000002
    LDR  r5, =0x00000001
    LDR  r6, =0x00000000
    LDR  r7, =0x00000000
    BL   init_gpio_pin
    MOVS r3, #10
    BL   init_gpio_pin

    // Initialize the I2C1 peripheral.
    // i2c_[cr1_]base:        0x40005400
    // i2c_cr2_base:          0x40005404
    // i2c_timingr_base:      0x40005410
    // i2c_isr_base:          0x40005418
    // First, disable I2C1 by resetting PE in I2C1_CR1.
    LDR  r0, =0x40005400
    LDR  r2, =0xFFFFFFFE
    BL   read_mod_and_write
    // Next, clear a few other bits in CR1 to 'reset' states:
    // (ST's standard periph library recommends 0x00CFE0FF)
    // We can also configure the analog and digital filter; so
    // enable the analog filter, but 0x00 for a digital filter.
    // So, reset I2C_CR1[12:8] ANFOFF and DNF stay low.
    LDR  r2, =0x00CFE0FF
    BL   read_mod_and_write
    // Configure I2C timing. (& with clear mask, 0xF0FFFFFF)
    // I'm not going to use that mask though...it's in the
    // standard peripheral library, but the datasheet says that
    // TIMINGR[27:24] are reserved.
    LDR  r0, =0x40005410
    LDR  r2, =0x0F000000
    BL   read_mod_and_write
    //LDR  r2, =0x00210507
    // Should be 1MHz@48MHz ('fast mode+')
    LDR  r2, =0x50100103
    // Should be 400KHz@48MHz ('fast mode')
    //LDR  r2, =0x50330309
    // Checking the reference manual, this should be 100KHz@48MHz
    //LDR  r2, =0xB0420F13
    // Checking the reference manual, this should be 10KHz@48MHz
    //LDR  r2, =0xB042C3C7
    BL   read_mod_orr_write
    /* (Own Address 1 config could go here; not used.) */
    /* (Enable the I2C Peripheral? Moved below) */
    // (Configure I2C mode goes here, but we leave the SMB[DH]EN
    // bits cleared from the CR1 mask step.)
    // Clear I2C1_CR2 with a reset mask, and then set ACK config.
    // Again, 0x07FF7FFF is recommended in the std periph lib.
    // But I will use 0x04... to clear AUTOEND/RELOAD.
    LDR  r0, =0x40005404
    LDR  r2, =0x04FF7FFF
    BL   read_mod_and_write
    // (Ack_Enable is 0, so no bit sets needed.)
    // Finally, enable the I2C1 peripheral in CR1.
    LDR  r0, =0x40005400
    LDR  r2, =0x00000001
    BL   read_mod_orr_write

    // Now, we need to start communicating with the SSD1306
    // driver and initialize the OLED screen.
    // 'Display Off' = 0xAE
    LDR  r0, =0x40005400
    LDR  r3, =0x000000AE
    BL   i2c_send_command
    // Set display clock division; recommended value of 0x80
    // (Command: 0xD5, and apparently the arg is cmd not dat.)
    LDR  r3, =0x000000D5
    BL   i2c_send_command
    LDR  r3, =0x00000080
    //LDR  r3, =0x000000F0
    BL   i2c_send_command
    // 'Set Multiplex' command: 0xA8, recommended 0x3F (1:64)
    LDR  r3, =0x000000A8
    BL   i2c_send_command
    LDR  r3, =0x0000003F
    BL   i2c_send_command
    // Set display offset to 0; command is 0xD3
    LDR  r3, =0x000000D3
    BL   i2c_send_command
    LDR  r3, =0x00000000
    BL   i2c_send_command
    // 'Set Start Line' command = 0b01xxxxxx for line x. Use 0.
    LDR  r3, =0x00000040
    BL   i2c_send_command
    // Internal charge pump settings; 0x14 on, 0x10 off.
    // (Command: 0x8D)
    LDR  r3, =0x0000008D
    BL   i2c_send_command
    LDR  r3, =0x00000014
    BL   i2c_send_command
    // 'Memory Mode' command: 0x20
    // 0x00 means 'act like ks0108' according to Adafruit...okay
    // (Seems to mean 'horizontal addressing' - 01 for vert.)
    LDR  r3, =0x00000020
    BL   i2c_send_command
    LDR  r3, =0x00000000
    // ...and '10' means 'page addressing mode'.
    //LDR  r3, =0x00000010
    BL   i2c_send_command
    // 'SEGREMAP' of 0x1. (|| with command 0xA0) Uh...I dunno.
    LDR  r3, =0x000000A1
    BL   i2c_send_command
    // 'COMSCANDEC' command: 0xC8 ('...INC' = 0xC0)
    LDR  r3, =0x000000C8
    BL   i2c_send_command
    // 'SETCOMPINS' command: 0xDA, recommended value 0x12
    LDR  r3, =0x000000DA
    BL   i2c_send_command
    LDR  r3, =0x00000012
    BL   i2c_send_command
    // 'Set Contrast' command: 0x81. With internal charge pump,
    // use value of 0xCF.
    LDR  r3, =0x00000081
    BL   i2c_send_command
    LDR  r3, =0x000000CF
    //LDR  r3, =0x000000FF
    BL   i2c_send_command
    // 'Set Precharge' command: 0xD9. With internal charge pump,
    // use value of 0xF1.
    LDR  r3, =0x000000D9
    BL   i2c_send_command
    LDR  r3, =0x000000F1
    //LDR  r3, =0x00000022
    BL   i2c_send_command
    // 'Set VCOM Detect' command: 0xDB, recommended 0x40?
    LDR  r3, =0x000000DB
    BL   i2c_send_command
    LDR  r3, =0x00000040
    //LDR  r3, =0x00000020
    BL   i2c_send_command
    // 'DISPLAYALLON_RESUME' command: 0xA4
    // (Output follows RAM content)
    LDR  r3, =0x000000A4
    BL   i2c_send_command
    // 'Normal Display Mode' command: 0xA6
    // ('Invert Display Mode' command: 0xA7)
    LDR  r3, =0x000000A6
    BL   i2c_send_command
    // Set Page start address.
    //LDR  r3, =0x000000B0
    //BL   i2c_send_command
    // Set high column address.
    /*
    LDR  r3, =0x00000010
    BL   i2c_send_command
    // Set low column address.
    LDR  r3, =0x00000001
    BL   i2c_send_command
    */
    // 'Display On' command: 0xAF
    LDR  r3, =0x000000AF
    BL   i2c_send_command

    oled_init_done:
    // Infinite 'set/increment' loop to signal that we have
    // reached the end of the program.
    //LDR  r1, =0xF00D
    // Flash the screen back and forth.
    //LDR  r3, =0x000003E8
    //LDR  r4, =0xFFFFFFFF
    LDR  r4, =0x00000000
    MOVS r0, r4
    BL   clear_oled_framebuffer
    LDR  r3, =0x00000001
    BL   draw_smiley_face
    // Draw a test outline-d rectangle.
    MOVS r0, #10
    MOVS r1, #10
    MOVS r2, #1
    MOVS r3, #0
    MOVS r4, #4
    MOVS r5, #8
    BL   i2c_draw_rect
    // Draw a test filled rectangle.
    MOVS r0, #110
    MOVS r1, #50
    MOVS r2, #1
    MOVS r3, #1
    MOVS r4, #5
    MOVS r5, #20
    BL   i2c_draw_rect
    MOVS r0, #0
    MOVS r1, #6
    MOVS r3, #1
    LDR  r2, =_sheap
    // (Add 1KB, for end of framebuffer.)
    LDR  r3, =0x00000400
    ADDS r2, r2, r3
    // And then put a test string there.
    MOVS r3, #72        // 'H'
    MOVS r4, #101       // 'e'
    LSLS r3, r3, #8
    ORRS r3, r3, r4
    MOVS r4, #108       // 'l'
    LSLS r3, r3, #8
    ORRS r3, r3, r4
    MOVS r4, #108       // 'l'
    LSLS r3, r3, #8
    ORRS r3, r3, r4
    STR  r3, [r2]
    ADDS r2, r2, #4
    MOVS r3, #111       // 'o'
    MOVS r4, #0
    LSLS r3, r3, #8
    ORRS r3, r3, r4
    LSLS r3, r3, #16
    STR  r3, [r2]
    SUBS r2, r2, #4
    MOVS r3, #1
    BL   i2c_draw_text
    main_loop:
        //ADDS r0, r0, #1
        //MOVS r0, r4
        //BL   clear_oled_framebuffer
        BL   i2c_display_framebuffer_try2
        //BL   i2c_display_framebuffer
        //LDR  r3, =0x000001F4
        //BL   delay_ms
        //MVNS r4, r4
        //MOVS r0, r4
        //BL   clear_oled_framebuffer
        B    main_loop
.size main, .-main
