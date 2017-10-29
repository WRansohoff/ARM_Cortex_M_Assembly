#ifndef _VVC_UTIL_ASM
#define _VVC_UTIL_ASM

/*
 * Utility functions, for better legibility.
 */

.syntax unified
.cpu cortex-m0plus
.fpu softvfp
.thumb

// Instead of #include'ing this file everywhere, we can
// just declare the methods 'global' and make sure our
// Makefile compiles/links with this source file.
.global read_mod_orr_write
.global read_mod_and_write
.global delay_us
.global delay_ms

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
 * (10 microseconds, for simplicity...)
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
 * Write a '0' to a WS2812 control pin. This means:
 * 'high' for 0.40 us, 'low' for 0.85 us.
 * Expects:
 *  r0 contains the GPIO ODR address.
 *  r1 contains the GPIO pin mask.
 * Writes:
 *  r2 used to store timing progress.
 *  r3 used to store/mod register values
 */
.section .text.ws2812_write_0,"ax",%progbits
ws2812_write_0:
    // We already know that 1us = 48 clock cycles. So 0.05 us = 2.4 cycles.
    // A '0' is 0.40 microseconds high, 0.85 microseconds low.
    // 0.40us = 19.2 cycles, 0.85us = 40.8 cycles
    // We will round to 19 / 41. (Total: 60 cycles = 1.25us)
    // 19 cycles high: first, pull up the pin.
    LDR  r3, [r0]
    ORRS r3, r3, r1
    STR  r3, [r0]
    // wait 19 cycles. Branching technically takes 2 cycles
    // if we branch, so (-1) load a number, and then (-3*6)
    // subtract 1 and branch back to the loop if != 0.
    MOVS r2, #4
    ws2812_write_0_high_loop:
        SUBS r2, r2, #1
        BNE  ws2812_write_0_high_loop
    // Reset the pin.
    LDR  r3, [r0]
    MVNS r1, r1
    ANDS r3, r3, r1
    STR  r3, [r0]
    // 41 cycles low. (Then leave the pin down.)
    MOVS r2, #3
    ws2812_write_0_low_loop:
        SUBS r2, r2, #1
        BNE  ws2812_write_0_low_loop
    // (Finally, un-NOT the r1 pin mask to retain state)
    MVNS r1, r1
    // Technically this was 40 instructions; the final BNE took 1.
    // Still, even if we're a few cycles off (and we are,)
    // it should still work. This is precise ENOUGH.
    NOP
    BX    lr
.size ws2812_write_0, .-ws2812_write_0

/*
 * Write a '1' to a WS2812 control pin. This means:
 * 'high' for 0.80 us, 'low' for 0.45 us.
 * Expects:
 *  r0 contains the GPIO ODR address.
 *  r1 contains the GPIO pin mask.
 * Writes:
 *  r2 used to store timing progress.
 *  r3 used to store/mod register values
 *  r7 used to store NOT pin mask.
 */
.section .text.ws2812_write_1,"ax",%progbits
ws2812_write_1:
    // Similarly to the 'write_0' calculation (0.05us = 2.4 cycles),
    // A '1' is 0.80 microseconds high, 0.45 microseconds low.
    // 0.80us = 38.4 cycles, 0.45us = 21.6 cycles.
    // We will round to 38 / 22. (Total: 60 cycles = 1.25us)
    // 38 cycles high: first, pull up the pin.
    MVNS r7, r1
    LDR  r3, [r0]
    ORRS r3, r3, r1
    STR  r3, [r0]
    // Delay 38-ish cycles.
    MOVS r2, #9
    ws2812_write_1_high_loop:
        SUBS r2, r2, #1
        BNE  ws2812_write_1_high_loop
    // Reset the pin.
    LDR  r3, [r0]
    ANDS r3, r3, r7
    STR  r3, [r0]
    // 22 cycles low. (Then leave the pin down.)
    //MOVS r2, #1
    //ws2812_write_1_low_loop:
        //SUBS r2, r2, #1
        //BNE  ws2812_write_1_low_loop
    BX   lr
.size ws2812_write_1, .-ws2812_write_1

/*
 * 'Latch' the color values on a WS2812 pin.
 * This assumes that the pin is already low, and
 * simply delays >50us. It also uses the PUSH/POP instructions'
 * ability to save/restore a list of registers, to avoid
 * overwriting previous state. This is something that really
 * should be retroactively applied to the other 'functions.'..
 * Expects:
 *  N/A
 * Writes:
 *  N/A (r0 push/popped)
 */
.section .text.ws2812_latch,"ax",%progbits
ws2812_latch:
    PUSH { r0, lr }
    // Pull low for at least 50us to 'latch' the RGB value.
    MOVS r0, #100
    BL   delay_us
    POP  { r0, pc }
.size ws2812_latch, .-ws2812_latch

/*
 * Write a 24-bit color to a WS2812 pin.
 * Expects:
 *  r0 contains the GPIO ODR address.
 *  r1 contains the GPIO pin mask.
 *  r2 contains the color to write, from 0x00000000
 *     up to 0x00GGRRBB [RGB=F]
 * Writes:
 *  N/A
 */
.section .text.ws2812_write_color,"ax",%progbits
ws2812_write_color:
    PUSH { r4, r5, r6, lr }
    // Send Green bits first, then R, then B. (Per spec.)
    LDR  r4, =0x00800000
    // (r2 is used as a scratch register in the write_0/1 funcs)
    MOV  r6, r2
    MVNS r7, r1
    send_ws2812_color_bit:
        // &= with the current bit, send appropriate bit.
        MOV  r5, r6
        ANDS r5, r5, r4
        BNE  send_ws2812_color_1
        BL   ws2812_write_0
        B    next_ws2812_color_bit
        send_ws2812_color_1:
            LDR  r3, [r0]
            ORRS r3, r3, r1
            STR  r3, [r0]
            // Delay 38-ish cycles.
            MOVS r2, #9
            ws2812_color_1_high_loop:
                SUBS r2, r2, #1
                BNE  ws2812_color_1_high_loop
            // Reset the pin.
            LDR  r3, [r0]
            ANDS r3, r3, r7
            STR  r3, [r0]
            MOVS r2, #1
            ws2812_color_1_low_loop:
                SUBS r2, r2, #1
                BNE  ws2812_color_1_low_loop
        next_ws2812_color_bit:
            // Bit position >> 1, if == 0 we're done.
            LSRS r4, r4, #1
            BNE  send_ws2812_color_bit
    MOV  r2, r6
    POP  { r4, r5, r6, pc }
.size ws2812_write_color, .-ws2812_write_color

#endif
