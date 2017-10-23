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

#endif
