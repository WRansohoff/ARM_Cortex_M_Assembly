#ifndef _VVC_UTIL_ASM
#define _VVC_UTIL_ASM

/*
 * Utility functions, for better legibility.
 */

.syntax unified
#ifdef VVC_F0
    .cpu cortex-m0plus
#elif  VVC_F3
    .cpu cortex-m4
#endif
.fpu softvfp
.thumb

// Instead of #include'ing this file everywhere, we can
// just declare the methods 'global' and make sure our
// Makefile compiles/links with this source file.
.global read_mod_orr_write
.global read_mod_and_write
.global delay_us
.global delay_ms
.global init_gpio_pin

// Assembly functions for common I2C operations.
.global i2c_send_start
.global i2c_send_stop
.global i2c_set_saddr
.global i2c_num_bytes_to_send
.global i2c_send_byte
.global i2c_send_last_byte
.global i2c_send_command
.global i2c_send_data
.global i2c_display_framebuffer
.global i2c_display_framebuffer_try2
// Drawing functions for SSD1306 OLED i2c screens.
// Mostly affect the framebuffer memory, without communicating.
.global i2c_write_pixel
.global i2c_draw_rect
.global i2c_draw_text
.global letter_to_bytes
.global clear_oled_framebuffer
.global draw_smiley_face

/*
 * Read a memory address, OR it with a value, and write
 * that value back. Expects:
 *  r0 contains address to read/write
 *  r2 contains value to OR with.
 * Writes:
 *  r1 used to store/modify contents of memory at r0.
 */
.section .text.read_mod_orr_write,"ax",%progbits
read_mod_orr_write:
    LDR  r1, [r0]
    ORRS r1, r1, r2
    STR  r1, [r0]
    BX   lr
.size read_mod_orr_write, .-read_mod_orr_write

/*
 * Read a memory address, AND it with a value, and write
 * that value back. Expects:
 *  r0 contains address to read/write
 *  r2 contains value to AND with.
 * Writes:
 *  r1 used to store/modify contents of memory at r0.
 */
.section .text.read_mod_and_write,"ax",%progbits
read_mod_and_write:
    LDR  r1, [r0]
    ANDS r1, r1, r2
    STR  r1, [r0]
    BX   lr
.size read_mod_and_write, .-read_mod_and_write

/*
 * Delay a given number of microseconds.
 * Expects:
 *  r0 contains the number of microseconds to wait.
 * Writes:
 *  r1 used to store progress.
 *  r2 used to store a scaling value based on clock frequency.
 */
.section .text.delay_us,"ax",%progbits
delay_us:
    // We are running at 48MHz, so 10 microsecond is X cycles.
    // How long is 1 cycle? 1 / (48,000,000 * second).
    // How long is 1 us?    1 / (1,000,000 * second).
    // So 1 us = 48 clock cycles. I think.
    // I still need to confirm this with a scope, but it
    // looks about right when used for half-second delays...
    MOV  r1, r0
    ADDS r1, r1, #1
    delay_us_loop:
        // Spend 48 cycles cycling:
        // 4 instructions to subtract 1x us and check if done.
        // 44x instructions executing a 4-instruction loop
        // 11 times. Each 48 cycles is a us 'step'.
        /*
         * NOTE/TODO: This is not totally accurate!!
         * It turns out that 'branch' instructions take
         * 2 cycles, not 1, but only if they do take the branch.
         * So, 'BEQ' is 1 cycle if it does not branch, 2 if
         * it does. That means that this timing is slightly off.
         * But hey, it's close enough for government work.
         */
        MOVS r2, #44
        SUBS r1, r1, #1
        CMP  r1, #0
        BEQ  delay_us_done
        delay_us_subloop:
            SUBS r2, r2, #4
            CMP  r2, #0
            BEQ  delay_us_loop
            B    delay_us_subloop
        B    delay_us_loop
    delay_us_done:
        BX   lr
.size delay_us, .-delay_us

/*
 * Delay a given number of milliseconds.
 * Expects:
 *  r3 contains the number of milliseconds to wait.
 * Writes:
 *  r0 stores how many us to wait.
 *  r1 used to store progress.
 *  r2 used to store a scaling value based on clock frequency.
 */
.section .text.delay_ms,"ax",%progbits
delay_ms:
    PUSH { lr }
    // 1ms = 1000x 1us delay cycles. ...About...
    LDR  r1, =0x000003E8 // (1000)
    MOV  r0, r3
    MULS r0, r0, r1
    BL   delay_us
    POP  { pc }
.size delay_ms, .-delay_ms

/*
 * Initialize a GPIO pin.
 * Expects:
 *  r0 contains the GPIO bank's base address.
 *  r3 contains the pin # (not the pin mask, so pin 2 is 2 not 4)
 *  r4 contains the pin mode
 *  r5 contains the output type value.
 *  r6 contains the output speed value.
 *  r7 contains the pull-up/down setting.
 * Writes:
 *  Hopefully N/A - r1/r2 are used by and/orr writes, but
 *  they are also PUSH/POPped to/from the stack.
 */
.section .text.init_gpio_pin,"ax",%progbits
init_gpio_pin:
    // Store registers we'll use on the stack.
    PUSH { r1, r2, lr }

    // Reset/set mode. (MODER)
    MOVS r2, #3
    // (Shift twice for each pin; 2-bit option)
    LSLS r2, r2, r3
    LSLS r2, r2, r3
    MVNS r2, r2
    BL   read_mod_and_write
    MOVS r2, r4
    LSLS r2, r2, r3
    LSLS r2, r2, r3
    BL   read_mod_orr_write

    // Reset/set 'output type' (OTYPER)
    ADDS r0, r0, #4
    MOVS r2, #1
    LSLS r2, r2, r3
    MVNS r2, r2
    BL   read_mod_and_write
    MOVS r2, r5
    LSLS r2, r2, r3
    BL   read_mod_orr_write

    // Reset/set output speed. (OSPEEDR)
    ADDS r0, r0, #4
    MOVS r2, #3
    LSLS r2, r2, r3
    LSLS r2, r2, r3
    MVNS r2, r2
    BL   read_mod_and_write
    MOVS r2, r6
    LSLS r2, r2, r3
    LSLS r2, r2, r3
    BL   read_mod_orr_write

    // Reset/set pull-up/down setting. (PUPDR)
    ADDS r0, r0, #4
    MOVS r2, #3
    LSLS r2, r2, r3
    LSLS r2, r2, r3
    MVNS r2, r2
    BL   read_mod_and_write
    MOVS r2, r7
    LSLS r2, r2, r3
    LSLS r2, r2, r3
    BL   read_mod_orr_write

    // Reset r0 register to the GPIO base address.
    SUBS r0, r0, #12

    // Pop stacked registers and branch back.
    POP  { r1, r2, pc }
.size init_gpio_pin, .-init_gpio_pin

/*
 * Send a 'start transmission' sequence over I2C
 * Expects:
 *   r0 contains the I2Cx_CR2 register location.
 * Writes:
 *   r1 used as scratch status register.
 */
.section .text.i2c_send_start,"ax",%progbits
i2c_send_start:
    PUSH { r2, lr }
    // 'Send start transmission' is bit 13 of I2Cx_CR2
    LDR  r2, =0x00002000
    BL   read_mod_orr_write
    // Wait for the start condition to manifest.
    i2c_wait_for_start:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        CMP  r1, r2
        BEQ  i2c_wait_for_start
    POP  { r2, pc }
.size i2c_send_start, .-i2c_send_start

/*
 * Send an 'end/stop transmission' sequence over I2C
 * Expects:
 *   r0 contains the I2Cx_CR2 register location.
 * Writes:
 *   r1 used as scratch status register.
 */
.section .text.i2c_send_stop,"ax",%progbits
i2c_send_stop:
    PUSH { r2, lr }
    // 'Send stop transmission' is bit 14 of I2Cx_CR2
    LDR  r2, =0x00004000
    BL   read_mod_orr_write
    // Wait for the stop condition to manifest.
    i2c_wait_for_stop:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        CMP  r1, r2
        BEQ  i2c_wait_for_stop
    // With a stop condition detected, clear the STOPF flag by
    // writing to STOPCF flag in I2C_ICR (Offset 0x1C)
    ADDS r0, r0, #24
    LDR  r2, =0x0000020
    BL   read_mod_orr_write
    // Wait for flag to clear in I2C_ISR (Offset 0x18)
    SUBS r0, r0, #4
    i2c_wait_for_stop_clear:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        CMP  r1, r2
        BEQ i2c_wait_for_stop_clear
    SUBS r0, r0, #20
    POP  { r2, pc }
.size i2c_send_stop, .-i2c_send_stop

/*
 * Set slave device address. I mean, that's what the manual
 * and even abbreviations call it; how about 'supplicant'?
 * Expects:
 *   r0 contains I2Cx_CR2 register address.
 *   r2 contains SADDR[7:0] 7-bit address: 0b0xxx-xxxx
 * Writes:
 *   r1 used as scratch register.
 *   r2 overwritten with corresponding CR2 mask.
 */
.section .text.i2c_set_saddr,"ax",%progbits
i2c_set_saddr:
    PUSH { lr }
    //LSLS r2, r2, #1
    BL   read_mod_orr_write
    POP  { pc }
.size i2c_set_saddr, .-i2c_set_saddr

/*
 * Set how many bytes a transmission will contain.
 * Expects:
 *   r0 contains I2Cx_CR2 register address.
 *   r2 contains total # of bytes to send.
 * Writes:
 *   r1 used as scratch register.
 */
.section .text.i2c_num_bytes_to_send,"ax",%progbits
i2c_num_bytes_to_send:
    MOVS r1, r2
    PUSH { r2, r3, lr }
    // Perform a slightly more complex load/modify/store,
    // to clear then set the 8 NYBYTES bits.
    // Reset NBYTES to 0, then set to the desired value.
    LDR  r3, [r0]
    LDR  r2, =0xFF00FFFF
    ANDS r3, r3, r2
    // Shift to NBYTES location; [23:16] from [7:0], << 16.
    MOVS r2, r1
    LSLS r2, #16
    ORRS r3, r3, r2
    STR  r3, [r0]
    POP  { r2, r3, pc }
.size i2c_num_bytes_to_send, .-i2c_num_bytes_to_send

/*
 * Send a byte of data over I2C.
 * Expects:
 *   - I2Cx peripheral is in an active transmission ('START' sent)
 *   r0 contains I2Cx[_CR1] base register address.
 *   r2 contains the byte to write; 0x000000BB.
 *   r3 contains the 'success' flag:
 *       TXIS    (standard): 0x00000002
 *       TC     (last byte): 0x00000040
 *       TCR (reload ready): 0x00000080
 * Writes:
 *   r1 used as scratch/progress register.
 */
.section .text.i2c_send_byte,"ax",%progbits
i2c_send_byte:
    // Setup/backup data. We only want to write to r1, not 2-3.
    MOVS r1, r2
    PUSH { r2, r4, lr }
    MOVS r2, r1
    // Target the TXDR buffer (0x28 = 40)
    ADDS r0, #40
    // Write/modify/store to the TX buffer.
    // (Clear the TX bits first :/)
    LDR  r1, =0xFFFFFF00
    LDR  r4, [r0]
    ANDS r4, r4, r1
    // Ensure that we only write bits [7:0]
    LDR  r1, =0x000000FF
    ANDS r2, r2, r1
    ORRS r4, r4, r2
    // Store the value to transmit.
    STR  r4, [r0]

    // Wait for the TXIS bit to be set in I2Cx_ICR.
    // (Offset 0x18 = 24, 40-24=16)
    SUBS r0, #16
    MOVS r2, r3
    // (Load the status register for debug)
    LDR  r4, =0x40005404
    LDR  r4, [r4]
    i2c_send_byte_tx_wait:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  i2c_send_byte_tx_wait

    // Reset the address register that was passed in.
    SUBS r0, #24
    // Return.
    POP { r2, r4, pc }
.size i2c_send_byte, .-i2c_send_byte

/*
 * Send a 'last byte' of data over I2C. Similar to 'i2c_send_byte'
 * Basically, we expect the 'TC' flag to be set instead of 'TXIS'.
 * ('Transfer Complete' vs. 'Ready for Next Byte')
 * Expects:
 *   - I2Cx peripheral is in an active transmission ('START' sent)
 *   r0 contains I2Cx[_CR1] base register address.
 *   r2 contains the byte to write; 0x000000BB.
 * Writes:
 *   r1 used as scratch/progress register.
 */
.section .text.i2c_send_last_byte,"ax",%progbits
i2c_send_last_byte:
    // Setup/backup data. We only want to write to r1, not 2-3.
    MOVS r1, r2
    PUSH { r2, r3, lr }
    MOVS r2, r1
    // Target the TXDR buffer (0x28 = 40)
    ADDS r0, #40
    // Ensure that we only write bits [7:0]
    LDR  r1, =0x000000FF
    ANDS r2, r2, r1
    // Write data to the TXDR buffer.
    BL   read_mod_orr_write

    // Wait for the TC bit to be set in I2Cx_ICR.
    // (Offset 0x18 = 24, 40-24=16)
    SUBS r0, #16
    LDR  r2, =0x00000040
    i2c_send_last_byte_tx_wait:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  i2c_send_last_byte_tx_wait

    // Reset the address register that was passed in.
    SUBS r0, #24
    // Return.
    POP { r2, r3, pc }
.size i2c_send_last_byte, .-i2c_send_last_byte


/*
 * Send a command over I2C.
 * Expects:
 *   r0 contains I2Cx[_CR1] base address.
 *   r3 contains command byte. (0x000000BB)
 * Writes:
 *   r1 used as scratch register.
 *   r2 used as scratch register.
 *   r3 overwritten.
 *   r7 used for a debug delay, if it isn't commented out.
 */
.section .text.i2c_send_command,"ax",%progbits
i2c_send_command:
    // I think these MOVSs are unnecessary; PUSH probably retains
    // the old register value? TODO
    PUSH { r4, lr }
    MOVS r4, r3
    // 'D/C' here is indicated by the first byte.
    // 0x00 means 'command / active'
    // i2c1_cr2_base:         0x40005404
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    // Set the screen's SADD[7:0] bits.
    // My breakout defaults to 0x78, 0x7A configurable by jumper.
    LDR  r2, =0x78
    BL   i2c_set_saddr
    // Send 2 bytes; 'D/C', then the actual content.
    MOVS r2, #2
    BL   i2c_num_bytes_to_send
    BL   i2c_send_start
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    LDR  r2, =0x00000000
    LDR  r3, =0x00000002
    BL   i2c_send_byte
    MOVS r2, r4
    LDR  r3, =0x00000040
    BL   i2c_send_byte
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4

    // Debug delay
    /*
    MOVS r7, r0
    MOVS r0, #100
    BL   delay_us
    MOVS r0, r7
    */

    POP  { r4, pc }
.size i2c_send_command, .-i2c_send_command

/*
 * Send a byte of data over I2C.
 * Expects:
 *   r0 contains I2Cx[_CR1] base address.
 *   r3 contains data byte. (0x000000BB)
 * Writes:
 *   r1 used as scratch register.
 *   r2 used as scratch register.
 */
.section .text.i2c_send_data,"ax",%progbits
i2c_send_data:
    // This is probably uneccessary MOVS'ing, I really should figure this out.
    MOVS r1, r3
    PUSH { r3, r4, lr }
    MOVS r3, r1
    MOVS r4, r3
    // 'D/C' here is indicated by the first byte.
    // 0x40 means 'data / active'
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    // Set the screen's SADD[7:0] bits.
    // My breakout defaults to 0x78, 0x7A configurable by jumper.
    LDR  r2, =0x78
    BL   i2c_set_saddr
    // Send 2 bytes; 'D/C', then the actual content.
    MOVS r2, #2
    BL   i2c_num_bytes_to_send
    BL   i2c_send_start
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    LDR  r2, =0x00000040
    LDR  r3, =0x00000002
    BL   i2c_send_byte
    MOVS r2, r4
    LDR  r4, =0x000000FF
    ANDS r2, r2, r4
    LDR  r3, =0x00000040
    BL   i2c_send_byte
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    POP { r3, r4, pc }
.size i2c_send_data, .-i2c_send_data

/*
 * Copy the current framebuffer into the OLED.
 * Note: Framebuffer RAM is [heap_start:+1024]
 * Expects:
 *   N/A
 * Writes:
 *   N/A
 */
.section .text.i2c_display_framebuffer,"ax",%progbits
i2c_display_framebuffer:
    PUSH { r0, r1, r2, r3, r4, r5, r6, lr }
    // Start/end of framebuffer memory
    LDR  r5, =_sheap
    LDR  r4, =0x00000400
    ADDS r4, r4, r5
    /*
     * In a single I2C transmission, write one 128B page
     * simply like, '0x40 / 0xdat / 0xdat / 0xdat / ...'
     * No need for interleaved 'DAT/CMD' bytes.
     * This chip can only send up to 255 bytes at once,
     * so first enable the 'RELOAD' flag in CR2.
     */
    LDR  r0, =0x40005400
    /*
    LDR  r3, =0x00000010
    BL   i2c_send_command
    LDR  r3, =0x00000001
    BL   i2c_send_command
    LDR  r3, =0x00000040
    BL   i2c_send_command
    */
    LDR  r3, =0x00000021
    BL   i2c_send_command
    MOVS r3, #0
    BL   i2c_send_command
    MOVS r3, #127
    BL   i2c_send_command
    LDR  r3, =0x00000022
    BL   i2c_send_command
    MOVS r3, #0
    BL   i2c_send_command
    MOVS r3, #7
    BL   i2c_send_command
    //LDR  r3, =0x00000040
    //BL   i2c_send_command
    // Enable the RELOAD flag.
    ADDS r0, r0, #4
    LDR  r2, =0x01000000
    BL   read_mod_orr_write
    // Set address
    LDR  r2, =0x78
    BL   read_mod_orr_write
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    MOVS r6, #8
    SUBS r5, r5, #4
    send_framebuffer_oled_row:
        LDR  r0, =0x40005404
        CMP  r6, #8
        BEQ  send_framebuffer_skip_stop
        //LDR  r4, =0x00000001
        //ANDS r4, r4, r6
        //BNE  i2c_continue_send
        BL   i2c_send_stop
        send_framebuffer_skip_stop:
        MOVS r4, #129
        MOVS r2, r4
        BL   i2c_num_bytes_to_send
        BL   i2c_send_start
        // Reset r0 to I2Cx_base
        SUBS r0, r0, #4
        LDR  r2, =0x00000040
        LDR  r3, =0x00000002
        BL   i2c_send_byte
        SUBS r4, r4, #1
        B    i2c_fb_sendforreal
        /*
        i2c_continue_send:
        MOVS r4, #128
        MOVS r2, r4
        BL   i2c_num_bytes_to_send
        // Reset r0 to I2Cx_base
        SUBS r0, r0, #4
        */
        i2c_fb_sendforreal:
        // Send bytes according to framebuffer progress. (r5)
        send_oled_row_bits:
            ADDS r5, r5, #4
            LDR  r2, [r5]
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            LDR  r2, [r5]
            LSRS r2, r2, #8
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            LDR  r2, [r5]
            LSRS r2, r2, #8
            LSRS r2, r2, #8
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            LDR  r2, [r5]
            LSRS r2, r2, #8
            LSRS r2, r2, #8
            LSRS r2, r2, #8
            CMP  r4, #4
            BNE  send_framebuffer_normal_byte4
            LDR  r3, =0x00000080
            BL   i2c_send_byte
            B    send_framebuffer_bytes_done
            send_framebuffer_normal_byte4:
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            send_framebuffer_bytes_done:
            SUBS r4, r4, #4
            BNE  send_oled_row_bits
        SUBS r6, r6, #1
        BNE  send_framebuffer_oled_row
    // Disable the RELOAD flag.
    LDR  r0, =0x40005404
    LDR  r2, =0xFEFFFFFF
    BL   read_mod_and_write
    BL   i2c_send_stop
    POP  { r0, r1, r2, r3, r4, r5, r6, pc }
.size i2c_display_framebuffer, .-i2c_display_framebuffer

/*
 * Another try at displaying the framebuffer; maybe more
 * slowly, just send 1 byte at a time.
 */
.section .text.i2c_display_framebuffer_try2,"ax",%progbits
i2c_display_framebuffer_try2:
    PUSH { r0, r1, r2, r3, r4, r5, r6, lr }
    // Start/end of framebuffer memory
    LDR  r5, =_sheap
    LDR  r4, =0x00000400
    ADDS r4, r4, r5
    // Send initialization commands.
    LDR  r0, =0x40005400
    LDR  r3, =0x00000021
    BL   i2c_send_command
    MOVS r3, #0
    BL   i2c_send_command
    MOVS r3, #127
    BL   i2c_send_command
    LDR  r3, =0x00000022
    BL   i2c_send_command
    MOVS r3, #0
    BL   i2c_send_command
    MOVS r3, #7
    BL   i2c_send_command
    LDR  r3, =0x00000040
    BL   i2c_send_command
    // Send data. (Technically 32 bits but w/e)
    i2c_display_fb_try2_send_bit:
        LDR  r3, [r5]
        BL   i2c_send_data
        LSRS r3, r3, #8
        BL   i2c_send_data
        LSRS r3, r3, #8
        BL   i2c_send_data
        LSRS r3, r3, #8
        BL   i2c_send_data
        ADDS r5, r5, #4
        CMP  r5, r4
        BNE  i2c_display_fb_try2_send_bit
    POP  { r0, r1, r2, r3, r4, r5, r6, pc }
.size i2c_display_framebuffer_try2, .-i2c_display_framebuffer_try2

/*
 * Write to a given (x, y) pixel.
 * Expects:
 *   r0 contains X value.
 *   r1 contains Y value.
 *   r2 contains pixel value (1/0).
 * Writes:
 *   N/A
 */
.section .text.i2c_write_pixel,"ax",%progbits
i2c_write_pixel:
    PUSH { r3, r4, r5, r6, r7, lr }
    // X byte offset (word-aligned)
    MOVS r3, r0
    LSRS r3, r3, #2
    LSLS r3, r3, #2
    // X bit offset (within a word)
    MOVS r4, r0
    MOVS r5, #3
    ANDS r4, r4, r5
    LSLS r4, r4, #3
    // Y page byte offset in FB (word-aligned)
    MOVS r5, r1
    LSRS r5, r5, #3
    LSLS r5, r5, #7
    // Y row bit offset (within a word)
    MOVS r6, r1
    MOVS r7, #7
    ANDS r6, r6, r7
    // Find the appropriate word.
    ADDS r3, r3, r5
    // (Plus start of heap, the FB's base address)
    LDR  r5, =_sheap
    ADDS r3, r3, r5
    LDR  r5, [r3]
    // ...and write the appropriate bit within it.
    ADDS r4, r4, r6
    MOVS r7, r2
    LSLS r7, r7, r4
    MVNS r7, r7
    ANDS r5, r5, r7
    MVNS r7, r7
    ORRS r5, r5, r7
    STR  r5, [r3]
    /*
     * (This is if the framebuffer were a normal format...
     *  but sadly it writes 1 byte = 1 8-pixel vertical line.)
    // Step 1: Find the right column. Use the Y-coordinate.
    // Width = 128 (0x80) so column = ...memloc >> 7 maybe?
    // And column X has memory location (128 * C)
    // So ...uh, maybe just << 7? Should be on a by-4 offset.
    // Except it's not just 128, it's 128 bits which is 16 bytes.
    // Which means << 4. No wait, 5? Shit, 3?
    MOVS r4, r1
    LSLS r4, r4, #4
    // Get the closest 32-bit offset to the pixel.
    // 1x 4-byte offset means 32 bits, so...
    // 1. Word offset is 1st 5 bits. (r5)
    // 2. X mem value 0s 1st 5 bits. (r3)
    MOVS r3, r0
    MOVS r5, r0
    LDR  r6, =0x0000001F
    ANDS r5, r5, r6
    MVNS r6, r6
    ANDS r3, r3, r6
    LSRS r3, r3, #5
    LSLS r3, r3, #2
    // Total mem address = (X mem value) + (Y col offset)
    ADDS r3, r3, r4
    // (Plus start of heap, the FB's base address)
    LDR  r4, =_sheap
    ADDS r3, r3, r4
    // Load the memory address.
    LDR  r6, [r3]
    // Modify the proper bit.
    MOVS r4, r2
    LSLS r4, r5
    ORRS r6, r6, r4
    // Store the word.
    STR r6, [r3]
    */
    POP  { r3, r4, r5, r6, r7, pc }
.size i2c_write_pixel, .-i2c_write_pixel

/*
 * Function to draw a rectangle on the screen.
 * Expects:
 *  - r0: X-coordinate of upper-left.
 *  - r1: Y-coordinate of upper-left.
 *  - r2: Color bit (0 or 1) to draw with.
 *  - r3: 0 for 1px outline, 1 to fill.
 *  - r4: Rectangle width.
 *  - r5: Rectangle height.
 *   (Please don't make w/h 0, method won't handle that yet.)
 * Writes:
 */
.section .text.i2c_draw_rect,"ax",%progbits
i2c_draw_rect:
    PUSH { r0, r1, r4, r5, r6, r7, lr }
    MOVS r6, r4
    ADDS r6, r6, r0
    MOVS r7, r5
    ADDS r7, r7, r1
    // (So now, r6 = max X and r7 = max Y.)
    // Move along each X row, down 1 y, repeat.
    // If r4 is 0, only fill when x or y = their min/max values.
    MOVS r4, r0
    MOVS r5, r1
    SUBS r1, r1, #1
    i2c_draw_rect_row:
        ADDS r1, r1, #1
        MOVS r0, r4
        SUBS r0, r0, #1
        i2c_draw_rect_row_px:
            ADDS r0, r0, #1
            CMP  r3, #0
            BNE  i2c_do_draw_rect_row_px
            // If we're in 'outline' mode, only draw the pixel:
            // - if we're at the min. or max. X-coord
            // - if we're at the min. or max. Y-coord.
            CMP r0, r4
            BEQ i2c_do_draw_rect_row_px
            CMP r0, r6
            BEQ i2c_do_draw_rect_row_px
            CMP r1, r5
            BEQ i2c_do_draw_rect_row_px
            CMP r1, r7
            BEQ i2c_do_draw_rect_row_px
            B   i2c_dont_draw_rect_row_px
            i2c_do_draw_rect_row_px:
                BL   i2c_write_pixel
            i2c_dont_draw_rect_row_px:
            CMP  r0, r6
            BNE  i2c_draw_rect_row_px
        // (We've reached the end of the row.)
        CMP  r1, r7
        BNE  i2c_draw_rect_row
    // (We've reached the end of the rectangle.)
    POP  { r0, r1, r2, r3, r6, r7, pc }
.size i2c_draw_rect, .-i2c_draw_rect

/*
 * Function to draw text on the screen.
 * Will happily overrun the framebuffer or jump to the
 * next line, careful.
 * Expects:
 *  - r0: X-coordinate of upper-left.
 *  - r1: Y-page of upper-left.
 *      Note: For now, this will have to be (page*8) px, for simplicity.
 *  - r2: Memory address of C-style string to draw.
 *        (must be null-terminated)
 * Writes:
 *  N/A
 */
.section .text.i2c_draw_text,"ax",%progbits
i2c_draw_text:
    /*
     * So basically, here's what we're going to do.
     *  1. If the current character is '\0', stop.
     *  2. Mask the sprite into 5 bytes in 2 registers.
     *  3. Load them into the current FB memory location.
     *  4. Increment FB memory location by 1.5 words. (1px space)
     *  N. Move to the next character, and go to step 1.
     */
    PUSH { r3, r4, r5, r6, r7, lr }
    // Keep track of the memory address.
    // Start at (0, 0)
    LDR  r5, =_sheap
    // Y-coordinate is in pages; 1 page = 8px = 128B offset.
    MOVS r4, r1
    LSLS r4, r4, #7
    ADDS r5, r5, r4
    // X-coordinate offset is likewise offset, but just by 1B per px to
    // reflect the weird Y-coordinate paging.
    MOVS r4, r0
    // Uh...round down to the nearest word for now. TODO.
    LSRS r4, r4, #2
    LSLS r4, r4, #2
    ADDS r5, r5, r4
    // Keep track of the 'byte offset' - we only align with
    // a word every other time; 5 bytes + 1 for kerning = 6.
    i2c_draw_text_process_chars:
        // Get the current character.
        LDR  r6, [r2]
        //LDR  r7, =0x000000FF
        LDR  r7, =0xFF000000
        ANDS r6, r6, r7
        LSRS r6, r6, #24
        CMP  r6, #0
        BEQ  i2c_draw_text_done
        // Fill in (up to) 4 characters, then increment a word.
        // Get the current character's bytes.
        BL   letter_to_bytes
        // 4 characters = 1 word, and 6 bytes of framebuffer memory.
        // Write the current glyph to: 0xgggggggg | 1xgggg----
        // or... 1x----gggg ? (Yes!)
        STR  r6, [r5]
        ADDS r5, r5, #4
        //LSLS r7, r7, #16
        STR  r7, [r5]
        // Write the current glyph to: 1x----gggg | 2xgggggggg
        // or 1xgggg---- ? (Yes, but I've been using the wrong half?)
        // Get the next character.
        LDR  r6, [r2]
        LDR  r7, =0x00FF0000
        ANDS r6, r6, r7
        LSRS r6, r6, #16
        CMP  r6, #0
        BEQ  i2c_draw_text_done
        BL   letter_to_bytes
        //LDR  r4, =0xFFFF0000
        //ANDS r4, r4, r6
        MOVS r4, r6
        LSLS r4, r4, #16
        LDR  r3, [r5]
        ORRS r3, r3, r4
        STR  r3, [r5]
        ADDS r5, r5, #4
        //LSLS r6, r6, #16
        LDR  r4, =0xFFFF0000
        ANDS r6, r6, r4
        LSRS r6, r6, #16
        LSLS r7, r7, #16
        ORRS r6, r6, r7
        STR  r6, [r5]
        ADDS r5, r5, #4
        // Write the current glyph to: 3xgggggggg | 4xgggg----
        // or 4x----gggg ? (Yep!)
        LDR  r6, [r2]
        LDR  r7, =0x0000FF00
        ANDS r6, r6, r7
        LSRS r6, r6, #8
        CMP  r6, #0
        BEQ  i2c_draw_text_done
        BL   letter_to_bytes
        STR  r6, [r5]
        ADDS r5, r5, #4
        //LSLS r7, r7, #16
        STR  r7, [r5]
        // Write the current glyph to: 4x----gggg | 5xgggggggg
        // or 4xgggg----? (Yes, but...uh, wrong half.)
        LDR  r6, [r2]
        LDR  r7, =0x000000FF
        ANDS r6, r6, r7
        CMP  r6, #0
        BEQ  i2c_draw_text_done
        BL   letter_to_bytes
        //LDR  r4, =0xFFFF0000
        //ANDS r4, r4, r6
        MOVS r4, r6
        LSLS r4, r4, #16
        LDR  r3, [r5]
        ORRS r3, r3, r4
        STR  r3, [r5]
        ADDS r5, r5, #4
        LDR  r4, =0xFFFF0000
        ANDS r6, r6, r4
        //LSLS r6, r6, #16
        LSRS r6, r6, #16
        LSLS r7, r7, #16
        ORRS r6, r6, r7
        STR  r6, [r5]
        ADDS r5, r5, #4
        // And on to the next <= 4 glyphs.
        i2c_draw_text_next_4chars:
        ADDS r2, r2, #4
        B    i2c_draw_text_process_chars
    i2c_draw_text_done:
    POP  { r3, r4, r5, r6, r7, pc }
.size i2c_draw_text, .-i2c_draw_text

/*
 * Get the 5 bytes representing a letter's glyph. (+1 pad for kerning)
 * This isn't super efficient; but whatever, it's a first draft.
 * For now, this doubles as the glyph map. So...yeah, not great.
 * Expects:
 *  r6: Which letter to find.
 * Writes:
 *  r6: First 4 bytes of the letter.
 *  r7: 5th byte of the letter. (0x0000xx00)
 * TODO: Letters not market with '*' are probably...uh, flipped.
 *       On at least one axis. I should fix that.
 */
.section .text.letter_to_bytes,"ax",%progbits
letter_to_bytes:
    PUSH { r0, r1, r2, r3, r4, r5, lr }
    MOVS r0, r6
    CMP  r0, #65
    BEQ  letter_to_bytes_load_A
    CMP  r0, #66
    BEQ  letter_to_bytes_load_B
    CMP  r0, #67
    BEQ  letter_to_bytes_load_C
    CMP  r0, #68
    BEQ  letter_to_bytes_load_D
    CMP  r0, #69
    BEQ  letter_to_bytes_load_E
    CMP  r0, #70
    BEQ  letter_to_bytes_load_F
    CMP  r0, #71
    BEQ  letter_to_bytes_load_G
    CMP  r0, #72
    BEQ  letter_to_bytes_load_H
    CMP  r0, #73
    BEQ  letter_to_bytes_load_I
    CMP  r0, #74
    BEQ  letter_to_bytes_load_J
    CMP  r0, #75
    BEQ  letter_to_bytes_load_K
    CMP  r0, #76
    BEQ  letter_to_bytes_load_L
    CMP  r0, #77
    BEQ  letter_to_bytes_load_M
    CMP  r0, #78
    BEQ  letter_to_bytes_load_N
    CMP  r0, #79
    BEQ  letter_to_bytes_load_O
    CMP  r0, #80
    BEQ  letter_to_bytes_load_P
    CMP  r0, #81
    BEQ  letter_to_bytes_load_Q
    CMP  r0, #82
    BEQ  letter_to_bytes_load_R
    CMP  r0, #83
    BEQ  letter_to_bytes_load_S
    CMP  r0, #84
    BEQ  letter_to_bytes_load_T
    CMP  r0, #85
    BEQ  letter_to_bytes_load_U
    CMP  r0, #86
    BEQ  letter_to_bytes_load_V
    CMP  r0, #87
    BEQ  letter_to_bytes_load_W
    CMP  r0, #88
    BEQ  letter_to_bytes_load_X
    CMP  r0, #89
    BEQ  letter_to_bytes_load_Y
    CMP  r0, #90
    BEQ  letter_to_bytes_load_Z
    B    letter_to_bytes_lowercase
    letter_to_bytes_load_A:
        LDR  r6, =0x1F688868
        LDR  r7, =0x00001F00
        B    letter_to_bytes_done
    letter_to_bytes_load_B:
        LDR  r6, =0xFF898989
        LDR  r7, =0x00007600
        B    letter_to_bytes_done
    letter_to_bytes_load_C:
        LDR  r6, =0x7E818181
        LDR  r7, =0x00006600
        B    letter_to_bytes_done
    letter_to_bytes_load_D:
        LDR  r6, =0xFF818181
        LDR  r7, =0x00007E00
        B    letter_to_bytes_done
    letter_to_bytes_load_E:
        LDR  r6, =0xFF898989
        LDR  r7, =0x00008100
        B    letter_to_bytes_done
    letter_to_bytes_load_F:
        LDR  r6, =0xFF888888
        LDR  r7, =0x00008000
        B    letter_to_bytes_done
    letter_to_bytes_load_G:
        LDR  r6, =0x7E818989
        LDR  r7, =0x00006E00
        B    letter_to_bytes_done
    letter_to_bytes_load_H: //*
        LDR  r6, =0x080808FF
        LDR  r7, =0x000000FF
        B    letter_to_bytes_done
    letter_to_bytes_load_I:
        LDR  r6, =0x8181FF81
        LDR  r7, =0x00008100
        B    letter_to_bytes_done
    letter_to_bytes_load_J:
        LDR  r6, =0x868181FE
        LDR  r7, =0x00008000
        B    letter_to_bytes_done
    letter_to_bytes_load_K:
        LDR  r6, =0xFF182442
        LDR  r7, =0x00008100
        B    letter_to_bytes_done
    letter_to_bytes_load_L:
        LDR  r6, =0xFF010101
        LDR  r7, =0x00000100
        B    letter_to_bytes_done
    letter_to_bytes_load_M:
        LDR  r6, =0xFF403040
        LDR  r7, =0x0000FF00
        B    letter_to_bytes_done
    letter_to_bytes_load_N:
        LDR  r6, =0xFF601806
        LDR  r7, =0x0000FF00
        B    letter_to_bytes_done
    letter_to_bytes_load_O:
        LDR  r6, =0x7E818181
        LDR  r7, =0x00007E00
        B    letter_to_bytes_done
    letter_to_bytes_load_P:
        LDR  r6, =0xFF888888
        LDR  r7, =0x00007000
        B    letter_to_bytes_done
    letter_to_bytes_load_Q:
        LDR  r6, =0x7E818582
        LDR  r7, =0x00007D00
        B    letter_to_bytes_done
    letter_to_bytes_load_R:
        LDR  r6, =0xFF888C8A
        LDR  r7, =0x00007100
        B    letter_to_bytes_done
    letter_to_bytes_load_S:
        LDR  r6, =0x66919989
        LDR  r7, =0x00006600
        B    letter_to_bytes_done
    letter_to_bytes_load_T:
        LDR  r6, =0x8080FF80
        LDR  r7, =0x00008000
        B    letter_to_bytes_done
    letter_to_bytes_load_U:
        LDR  r6, =0xFE010101
        LDR  r7, =0x0000FE00
        B    letter_to_bytes_done
    letter_to_bytes_load_V:
        LDR  r6, =0xE01C031C
        LDR  r7, =0x0000E000
        B    letter_to_bytes_done
    letter_to_bytes_load_W:
        LDR  r6, =0xFE010601
        LDR  r7, =0x0000FE00
        B    letter_to_bytes_done
    letter_to_bytes_load_X:
        LDR  r6, =0xC3241824
        LDR  r7, =0x0000C300
        B    letter_to_bytes_done
    letter_to_bytes_load_Y:
        LDR  r6, =0xE0100F10
        LDR  r7, =0x0000E000
        B    letter_to_bytes_done
    letter_to_bytes_load_Z:
        LDR  r6, =0x838599A1
        LDR  r7, =0x0000C100
        B    letter_to_bytes_done
    letter_to_bytes_lowercase:
    CMP  r0, #97
    BEQ  letter_to_bytes_load_a
    CMP  r0, #98
    BEQ  letter_to_bytes_load_b
    CMP  r0, #99
    BEQ  letter_to_bytes_load_c
    CMP  r0, #100
    BEQ  letter_to_bytes_load_d
    CMP  r0, #101
    BEQ  letter_to_bytes_load_e
    CMP  r0, #102
    BEQ  letter_to_bytes_load_f
    CMP  r0, #103
    BEQ  letter_to_bytes_load_g
    CMP  r0, #104
    BEQ  letter_to_bytes_load_h
    CMP  r0, #105
    BEQ  letter_to_bytes_load_i
    CMP  r0, #106
    BEQ  letter_to_bytes_load_j
    CMP  r0, #107
    BEQ  letter_to_bytes_load_k
    CMP  r0, #108
    BEQ  letter_to_bytes_load_l
    CMP  r0, #109
    BEQ  letter_to_bytes_load_m
    CMP  r0, #110
    BEQ  letter_to_bytes_load_n
    CMP  r0, #111
    BEQ  letter_to_bytes_load_o
    CMP  r0, #112
    BEQ  letter_to_bytes_load_p
    CMP  r0, #113
    BEQ  letter_to_bytes_load_q
    CMP  r0, #114
    BEQ  letter_to_bytes_load_r
    CMP  r0, #115
    BEQ  letter_to_bytes_load_s
    CMP  r0, #116
    BEQ  letter_to_bytes_load_t
    CMP  r0, #117
    BEQ  letter_to_bytes_load_u
    CMP  r0, #118
    BEQ  letter_to_bytes_load_v
    CMP  r0, #119
    BEQ  letter_to_bytes_load_w
    CMP  r0, #120
    BEQ  letter_to_bytes_load_x
    CMP  r0, #121
    BEQ  letter_to_bytes_load_y
    CMP  r0, #122
    BEQ  letter_to_bytes_load_z
    B    letter_to_bytes_numbers
    letter_to_bytes_load_a:
        LDR  r6, =0x06292929
        LDR  r7, =0x00001E00
        B    letter_to_bytes_done
    letter_to_bytes_load_b:
        LDR  r6, =0xFF090909
        LDR  r7, =0x00000600
        B    letter_to_bytes_done
    letter_to_bytes_load_c:
        LDR  r6, =0x1E212121
        LDR  r7, =0x00001200
        B    letter_to_bytes_done
    letter_to_bytes_load_d:
        LDR  r6, =0x060909FF
        LDR  r7, =0x00000100
        B    letter_to_bytes_done
    letter_to_bytes_load_e: //*
        LDR  r6, =0x9494947C
        LDR  r7, =0x0000005C
        B    letter_to_bytes_done
    letter_to_bytes_load_f:
        LDR  r6, =0x087F8888
        LDR  r7, =0x00006000
        B    letter_to_bytes_done
    letter_to_bytes_load_g:
        LDR  r6, =0x32494949
        LDR  r7, =0x00003E00
        B    letter_to_bytes_done
    letter_to_bytes_load_h:
        LDR  r6, =0xFF080808
        LDR  r7, =0x00000700
        B    letter_to_bytes_done
    letter_to_bytes_load_i:
        LDR  r6, =0x00005F00
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_j:
        LDR  r6, =0x0006015E
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_k:
        LDR  r6, =0x00FF1C23
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_l: //*
        LDR  r6, =0x00FF0000
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_m:
        LDR  r6, =0x3F101F10
        LDR  r7, =0x00000F00
        B    letter_to_bytes_done
    letter_to_bytes_load_n:
        LDR  r6, =0x3F10100F
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_o: //*
        LDR  r6, =0x88888870
        LDR  r7, =0x00000070
        B    letter_to_bytes_done
    letter_to_bytes_load_p:
        LDR  r6, =0x007F4848
        LDR  r7, =0x00003000
        B    letter_to_bytes_done
    letter_to_bytes_load_q:
        LDR  r6, =0x3048487E
        LDR  r7, =0x00000100
        B    letter_to_bytes_done
    letter_to_bytes_load_r:
        LDR  r6, =0x003F1010
        LDR  r7, =0x00000800
        B    letter_to_bytes_done
    letter_to_bytes_load_s:
        LDR  r6, =0x00324949
        LDR  r7, =0x00002600
        B    letter_to_bytes_done
    letter_to_bytes_load_t:
        LDR  r6, =0x20FE2121
        LDR  r7, =0x00000200
        B    letter_to_bytes_done
    letter_to_bytes_load_u:
        LDR  r6, =0x3C02023E
        LDR  r7, =0x00000300
        B    letter_to_bytes_done
    letter_to_bytes_load_v:
        LDR  r6, =0x18060106
        LDR  r7, =0x00001800
        B    letter_to_bytes_done
    letter_to_bytes_load_w:
        LDR  r6, =0x1E010201
        LDR  r7, =0x00001E00
        B    letter_to_bytes_done
    letter_to_bytes_load_x:
        LDR  r6, =0x110A040A
        LDR  r7, =0x00001100
        B    letter_to_bytes_done
    letter_to_bytes_load_y:
        LDR  r6, =0x3209093E
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_z:
        LDR  r6, =0x11131519
        LDR  r7, =0x00001100
        B    letter_to_bytes_done
    letter_to_bytes_numbers:
    CMP  r0, #48
    BEQ  letter_to_bytes_load_0
    CMP  r0, #49
    BEQ  letter_to_bytes_load_1
    CMP  r0, #50
    BEQ  letter_to_bytes_load_2
    CMP  r0, #51
    BEQ  letter_to_bytes_load_3
    CMP  r0, #52
    BEQ  letter_to_bytes_load_4
    CMP  r0, #53
    BEQ  letter_to_bytes_load_5
    CMP  r0, #54
    BEQ  letter_to_bytes_load_6
    CMP  r0, #55
    BEQ  letter_to_bytes_load_7
    CMP  r0, #56
    BEQ  letter_to_bytes_load_8
    CMP  r0, #57
    BEQ  letter_to_bytes_load_9
    CMP  r0, #58
    BEQ  letter_to_bytes_load_colon
    CMP  r0, #46
    BEQ  letter_to_bytes_load_period
    // Default to blank 0's.
    MOVS r6, #0
    MOVS r7, #0
    B    letter_to_bytes_done
    letter_to_bytes_load_0:
        LDR  r6, =0x7EE19987
        LDR  r7, =0x00007E00
        B    letter_to_bytes_done
    letter_to_bytes_load_1:
        LDR  r6, =0x2141FF01
        LDR  r7, =0x00000100
        B    letter_to_bytes_done
    letter_to_bytes_load_2:
        LDR  r6, =0x63878D99
        LDR  r7, =0x00007100
        B    letter_to_bytes_done
    letter_to_bytes_load_3:
        LDR  r6, =0x66818989
        LDR  r7, =0x00007600
        B    letter_to_bytes_done
    letter_to_bytes_load_4:
        LDR  r6, =0xF80808FF
        LDR  r7, =0x00000800
        B    letter_to_bytes_done
    letter_to_bytes_load_5:
        LDR  r6, =0xE2919191
        LDR  r7, =0x00008E00
        B    letter_to_bytes_done
    letter_to_bytes_load_6:
        LDR  r6, =0x7E919191
        LDR  r7, =0x00004E00
        B    letter_to_bytes_done
    letter_to_bytes_load_7:
        LDR  r6, =0x60838CB0
        LDR  r7, =0x0000C000
        B    letter_to_bytes_done
    letter_to_bytes_load_8:
        LDR  r6, =0x6E919191
        LDR  r7, =0x00006E00
        B    letter_to_bytes_done
    letter_to_bytes_load_9:
        LDR  r6, =0x72898989
        LDR  r7, =0x00007E00
        B    letter_to_bytes_done
    letter_to_bytes_load_colon:
        LDR  r6, =0x00002400
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_load_period:
        LDR  r6, =0x00000002
        LDR  r7, =0x00000000
        B    letter_to_bytes_done
    letter_to_bytes_done:
    POP  { r0, r1, r2, r3, r4, r5, pc }
.size letter_to_bytes, .-letter_to_bytes

/*
 * Clear the OLED framebuffer to a single value.
 * Expects:
 *   r0 contains the value to write. (32-bit, 0xFFFFFFFF or 0x0)
 * Writes:
 *   N/A
 */
.section .text.clear_oled_framebuffer,"ax",%progbits
clear_oled_framebuffer:
    PUSH { r1, r2, r4, lr }
    // Framebuffer start: ?
    LDR  r1, =_sheap
    // Framebuffer end:   ? + 1KB
    LDR  r2, =0x00000400
    ADDS r2, r2, r1
    clear_oled_fb_bits:
        LDR  r4, [r1]
        STR  r0, [r1]
        LDR  r4, [r1]
        ADDS r1, r1, #4
        CMP  r1, r2
        BNE  clear_oled_fb_bits
    POP  { r1, r2, r4, pc }
.size clear_oled_framebuffer, .-clear_oled_framebuffer

/*
 * Draw a smiley face to test the framebuffer/pixel drawing
 * functions.
 * Expects:
 *   r3 contains the monochrome color bit to draw with.
 * Writes:
 *   N/A
 */
.section .text.draw_smiley_face,"ax",%progbits
draw_smiley_face:
    PUSH { r0, r1, r2, lr }
    MOVS r0, r3
    // X/Y Draw the pixels for a smiley face
    MOVS r2, r3
    // Test draws.
    /*
    MOVS r1, #0
    MOVS r0, #0
    BL   i2c_write_pixel
    MOVS r0, #1
    BL   i2c_write_pixel
    MOVS r0, #2
    BL   i2c_write_pixel
    MOVS r0, #3
    BL   i2c_write_pixel
    MOVS r0, #4
    BL   i2c_write_pixel
    MOVS r0, #5
    BL   i2c_write_pixel
    MOVS r0, #6
    BL   i2c_write_pixel
    MOVS r0, #7
    BL   i2c_write_pixel
    MOVS r0, #8
    BL   i2c_write_pixel
    MOVS r0, #9
    BL   i2c_write_pixel
    MOVS r0, #10
    BL   i2c_write_pixel
    MOVS r0, #11
    BL   i2c_write_pixel
    */
    // Rows [20, 21, 22, 23]: Col [42, 43, 86, 87]
    MOVS r1, #20
    MOVS r0, #42
    BL   i2c_write_pixel
    MOVS r0, #43
    BL   i2c_write_pixel
    MOVS r0, #86
    BL   i2c_write_pixel
    MOVS r0, #87
    BL   i2c_write_pixel
    MOVS r1, #21
    MOVS r0, #42
    BL   i2c_write_pixel
    MOVS r0, #43
    BL   i2c_write_pixel
    MOVS r0, #86
    BL   i2c_write_pixel
    MOVS r0, #87
    BL   i2c_write_pixel
    MOVS r1, #22
    MOVS r0, #42
    BL   i2c_write_pixel
    MOVS r0, #43
    BL   i2c_write_pixel
    MOVS r0, #86
    BL   i2c_write_pixel
    MOVS r0, #87
    BL   i2c_write_pixel
    MOVS r1, #23
    MOVS r0, #42
    BL   i2c_write_pixel
    MOVS r0, #43
    BL   i2c_write_pixel
    MOVS r0, #86
    BL   i2c_write_pixel
    MOVS r0, #87
    BL   i2c_write_pixel
    // Rows [36, 37, 38, 39]: Col [31, 32, 96, 97]
    MOVS r1, #36
    MOVS r0, #31
    BL   i2c_write_pixel
    MOVS r0, #32
    BL   i2c_write_pixel
    MOVS r0, #96
    BL   i2c_write_pixel
    MOVS r0, #97
    BL   i2c_write_pixel
    MOVS r1, #37
    MOVS r0, #31
    BL   i2c_write_pixel
    MOVS r0, #32
    BL   i2c_write_pixel
    MOVS r0, #96
    BL   i2c_write_pixel
    MOVS r0, #97
    BL   i2c_write_pixel
    MOVS r1, #38
    MOVS r0, #31
    BL   i2c_write_pixel
    MOVS r0, #32
    BL   i2c_write_pixel
    MOVS r0, #96
    BL   i2c_write_pixel
    MOVS r0, #97
    BL   i2c_write_pixel
    MOVS r1, #39
    MOVS r0, #31
    BL   i2c_write_pixel
    MOVS r0, #32
    BL   i2c_write_pixel
    MOVS r0, #96
    BL   i2c_write_pixel
    MOVS r0, #97
    BL   i2c_write_pixel
    // Rows [40, 41]: Col [32, 33, 95, 96]
    MOVS r1, #40
    MOVS r0, #32
    BL   i2c_write_pixel
    MOVS r0, #33
    BL   i2c_write_pixel
    MOVS r0, #95
    BL   i2c_write_pixel
    MOVS r0, #96
    BL   i2c_write_pixel
    MOVS r1, #41
    MOVS r0, #32
    BL   i2c_write_pixel
    MOVS r0, #33
    BL   i2c_write_pixel
    MOVS r0, #95
    BL   i2c_write_pixel
    MOVS r0, #96
    BL   i2c_write_pixel
    // Row   42: Col [33, 34, 94, 95]
    MOVS r1, #42
    MOVS r0, #33
    BL   i2c_write_pixel
    MOVS r0, #34
    BL   i2c_write_pixel
    MOVS r0, #94
    BL   i2c_write_pixel
    MOVS r0, #95
    BL   i2c_write_pixel
    // Row   43: Col [33, 34, 35, 93, 94, 95]
    MOVS r1, #43
    MOVS r0, #33
    BL   i2c_write_pixel
    MOVS r0, #34
    BL   i2c_write_pixel
    MOVS r0, #35
    BL   i2c_write_pixel
    MOVS r0, #93
    BL   i2c_write_pixel
    MOVS r0, #94
    BL   i2c_write_pixel
    MOVS r0, #95
    BL   i2c_write_pixel
    // Row   44: Col [34, 35, 36, 92, 93, 94]
    MOVS r1, #44
    MOVS r0, #34
    BL   i2c_write_pixel
    MOVS r0, #35
    BL   i2c_write_pixel
    MOVS r0, #36
    BL   i2c_write_pixel
    MOVS r0, #92
    BL   i2c_write_pixel
    MOVS r0, #93
    BL   i2c_write_pixel
    MOVS r0, #94
    BL   i2c_write_pixel
    // Row   45: Col [35, 36, 37, 91, 92, 93]
    MOVS r1, #45
    MOVS r0, #35
    BL   i2c_write_pixel
    MOVS r0, #36
    BL   i2c_write_pixel
    MOVS r0, #37
    BL   i2c_write_pixel
    MOVS r0, #91
    BL   i2c_write_pixel
    MOVS r0, #92
    BL   i2c_write_pixel
    MOVS r0, #93
    BL   i2c_write_pixel
    // Row   46: Col [36, 37, 38, 90, 91, 92]
    MOVS r1, #46
    MOVS r0, #36
    BL   i2c_write_pixel
    MOVS r0, #37
    BL   i2c_write_pixel
    MOVS r0, #38
    BL   i2c_write_pixel
    MOVS r0, #90
    BL   i2c_write_pixel
    MOVS r0, #91
    BL   i2c_write_pixel
    MOVS r0, #92
    BL   i2c_write_pixel
    // Row   47: Col [37, 38, 39, 89, 90, 91]
    MOVS r1, #47
    MOVS r0, #37
    BL   i2c_write_pixel
    MOVS r0, #38
    BL   i2c_write_pixel
    MOVS r0, #39
    BL   i2c_write_pixel
    MOVS r0, #89
    BL   i2c_write_pixel
    MOVS r0, #90
    BL   i2c_write_pixel
    MOVS r0, #91
    BL   i2c_write_pixel
    // Row   48: Col [38, 39, 40, 88, 89, 90]
    MOVS r1, #48
    MOVS r0, #38
    BL   i2c_write_pixel
    MOVS r0, #39
    BL   i2c_write_pixel
    MOVS r0, #40
    BL   i2c_write_pixel
    MOVS r0, #88
    BL   i2c_write_pixel
    MOVS r0, #89
    BL   i2c_write_pixel
    MOVS r0, #90
    BL   i2c_write_pixel
    // Row   49: Col [39, 40, 41, 42, 86, 87, 88, 89]
    MOVS r1, #49
    MOVS r0, #39
    BL   i2c_write_pixel
    MOVS r0, #40
    BL   i2c_write_pixel
    MOVS r0, #41
    BL   i2c_write_pixel
    MOVS r0, #42
    BL   i2c_write_pixel
    MOVS r0, #86
    BL   i2c_write_pixel
    MOVS r0, #87
    BL   i2c_write_pixel
    MOVS r0, #88
    BL   i2c_write_pixel
    MOVS r0, #89
    BL   i2c_write_pixel
    // Row   50: Col [41, 42, 43, 44, 84, 85, 86, 87]
    MOVS r1, #50
    MOVS r0, #41
    BL   i2c_write_pixel
    MOVS r0, #42
    BL   i2c_write_pixel
    MOVS r0, #43
    BL   i2c_write_pixel
    MOVS r0, #44
    BL   i2c_write_pixel
    MOVS r0, #84
    BL   i2c_write_pixel
    MOVS r0, #85
    BL   i2c_write_pixel
    MOVS r0, #86
    BL   i2c_write_pixel
    MOVS r0, #87
    BL   i2c_write_pixel
    // Row   51: Col [43-47, 81-85]
    MOVS r1, #51
    MOVS r0, #43
    BL   i2c_write_pixel
    MOVS r0, #44
    BL   i2c_write_pixel
    MOVS r0, #45
    BL   i2c_write_pixel
    MOVS r0, #46
    BL   i2c_write_pixel
    MOVS r0, #47
    BL   i2c_write_pixel
    MOVS r0, #81
    BL   i2c_write_pixel
    MOVS r0, #82
    BL   i2c_write_pixel
    MOVS r0, #83
    BL   i2c_write_pixel
    MOVS r0, #84
    BL   i2c_write_pixel
    MOVS r0, #85
    BL   i2c_write_pixel
    // Row   52: Col [45-50, 78-83]
    MOVS r1, #52
    MOVS r0, #45
    BL   i2c_write_pixel
    MOVS r0, #46
    BL   i2c_write_pixel
    MOVS r0, #47
    BL   i2c_write_pixel
    MOVS r0, #48
    BL   i2c_write_pixel
    MOVS r0, #49
    BL   i2c_write_pixel
    MOVS r0, #50
    BL   i2c_write_pixel
    MOVS r0, #78
    BL   i2c_write_pixel
    MOVS r0, #79
    BL   i2c_write_pixel
    MOVS r0, #80
    BL   i2c_write_pixel
    MOVS r0, #81
    BL   i2c_write_pixel
    MOVS r0, #82
    BL   i2c_write_pixel
    MOVS r0, #83
    BL   i2c_write_pixel
    // Row   53: Col [48-54, 74-80]
    MOVS r1, #53
    MOVS r0, #48
    BL   i2c_write_pixel
    MOVS r0, #49
    BL   i2c_write_pixel
    MOVS r0, #50
    BL   i2c_write_pixel
    MOVS r0, #51
    BL   i2c_write_pixel
    MOVS r0, #52
    BL   i2c_write_pixel
    MOVS r0, #53
    BL   i2c_write_pixel
    MOVS r0, #54
    BL   i2c_write_pixel
    MOVS r0, #74
    BL   i2c_write_pixel
    MOVS r0, #75
    BL   i2c_write_pixel
    MOVS r0, #76
    BL   i2c_write_pixel
    MOVS r0, #77
    BL   i2c_write_pixel
    MOVS r0, #78
    BL   i2c_write_pixel
    MOVS r0, #79
    BL   i2c_write_pixel
    MOVS r0, #80
    BL   i2c_write_pixel
    // Row   54: Col [51-59, 71-79]
    MOVS r1, #54
    MOVS r0, #51
    BL   i2c_write_pixel
    MOVS r0, #52
    BL   i2c_write_pixel
    MOVS r0, #53
    BL   i2c_write_pixel
    MOVS r0, #54
    BL   i2c_write_pixel
    MOVS r0, #55
    BL   i2c_write_pixel
    MOVS r0, #56
    BL   i2c_write_pixel
    MOVS r0, #57
    BL   i2c_write_pixel
    MOVS r0, #58
    BL   i2c_write_pixel
    MOVS r0, #59
    BL   i2c_write_pixel
    MOVS r0, #71
    BL   i2c_write_pixel
    MOVS r0, #72
    BL   i2c_write_pixel
    MOVS r0, #73
    BL   i2c_write_pixel
    MOVS r0, #74
    BL   i2c_write_pixel
    MOVS r0, #75
    BL   i2c_write_pixel
    MOVS r0, #76
    BL   i2c_write_pixel
    MOVS r0, #77
    BL   i2c_write_pixel
    MOVS r0, #78
    BL   i2c_write_pixel
    MOVS r0, #79
    BL   i2c_write_pixel
    // Row   55: Col [55-75]
    MOVS r1, #55
    MOVS r0, #55
    BL   i2c_write_pixel
    MOVS r0, #56
    BL   i2c_write_pixel
    MOVS r0, #57
    BL   i2c_write_pixel
    MOVS r0, #58
    BL   i2c_write_pixel
    MOVS r0, #59
    BL   i2c_write_pixel
    MOVS r0, #60
    BL   i2c_write_pixel
    MOVS r0, #61
    BL   i2c_write_pixel
    MOVS r0, #62
    BL   i2c_write_pixel
    MOVS r0, #63
    BL   i2c_write_pixel
    MOVS r0, #64
    BL   i2c_write_pixel
    MOVS r0, #65
    BL   i2c_write_pixel
    MOVS r0, #66
    BL   i2c_write_pixel
    MOVS r0, #67
    BL   i2c_write_pixel
    MOVS r0, #68
    BL   i2c_write_pixel
    MOVS r0, #69
    BL   i2c_write_pixel
    MOVS r0, #70
    BL   i2c_write_pixel
    MOVS r0, #71
    BL   i2c_write_pixel
    MOVS r0, #72
    BL   i2c_write_pixel
    MOVS r0, #73
    BL   i2c_write_pixel
    MOVS r0, #74
    BL   i2c_write_pixel
    MOVS r0, #75
    BL   i2c_write_pixel
    // Row   56: Col [60-70]
    MOVS r1, #56
    MOVS r0, #60
    BL   i2c_write_pixel
    MOVS r0, #61
    BL   i2c_write_pixel
    MOVS r0, #62
    BL   i2c_write_pixel
    MOVS r0, #63
    BL   i2c_write_pixel
    MOVS r0, #64
    BL   i2c_write_pixel
    MOVS r0, #65
    BL   i2c_write_pixel
    MOVS r0, #66
    BL   i2c_write_pixel
    MOVS r0, #67
    BL   i2c_write_pixel
    MOVS r0, #68
    BL   i2c_write_pixel
    MOVS r0, #69
    BL   i2c_write_pixel
    MOVS r0, #70
    BL   i2c_write_pixel
    POP  { r0, r1, r2, pc }
.size draw_smiley_face, .-draw_smiley_face

#endif
