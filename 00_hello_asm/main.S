.long 0x20001000
.long _start

_start:

loop:
    ADD R0, R0, #1
b loop

.global _start
