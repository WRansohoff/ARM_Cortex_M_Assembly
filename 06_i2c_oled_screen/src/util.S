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
 * Writes:
 *   r1 used as scratch/progress register.
 */
.section .text.i2c_send_byte,"ax",%progbits
i2c_send_byte:
    // Setup/backup data. We only want to write to r1, not 2-3.
    MOVS r1, r2
    PUSH { r2, r3, lr }
    MOVS r2, r1
    // Target the TXDR buffer (0x28 = 40)
    ADDS r0, #40
    // Write/modify/store to the TX buffer.
    // (Clear the TX bits first :/)
    LDR  r1, =0xFFFFFF00
    LDR  r3, [r0]
    ANDS r3, r3, r1
    // Ensure that we only write bits [7:0]
    LDR  r1, =0x000000FF
    ANDS r2, r2, r1
    ORRS r3, r3, r2
    // Store the value to transmit.
    STR  r3, [r0]

    // Wait for the TXIS bit to be set in I2Cx_ICR.
    // (Offset 0x18 = 24, 40-24=16)
    SUBS r0, #16
    LDR  r2, =0x00000002
    i2c_send_byte_tx_wait:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  i2c_send_byte_tx_wait

    // Reset the address register that was passed in.
    SUBS r0, #24
    // Return.
    POP { r2, r3, pc }
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
 */
.section .text.i2c_send_command,"ax",%progbits
i2c_send_command:
    PUSH { lr }
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
    BL   i2c_send_byte
    MOVS r2, r3
    BL   i2c_send_last_byte
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4

    // Debug delay
    MOVS r7, r0
    MOVS r0, #100
    BL   delay_us
    MOVS r0, r7

    POP  { pc }
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
    PUSH { lr }
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
    BL   i2c_send_byte
    MOVS r2, r3
    BL   i2c_send_last_byte
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    POP { pc }
.size i2c_send_data, .-i2c_send_data

#endif
