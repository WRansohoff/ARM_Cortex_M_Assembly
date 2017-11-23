# Overview

Interface with an SSD1306 OLED screen over simple SDA/SCL I2C interface.

NOTE: While STM32F303 linker/boot/etc files are present, this will almost certainly only work with the STM32F030 - and maybe only the 20-pin package. You'll probably need to adjust the pin numbers, Alternate Function modes, etc for other chips. Refer to their datasheets for the appropriate values. Also, the TIMINGR register value is set up for 1MHz 'fast mode+' I2C speed on a 48MHz peripheral clock. I am not sure if the screen technically supports that, although it does work for me; Adafruit's libraries use 400KHz 'fast mode,' but they are also written for 8-bit AVRs. Anyways, there are commented-out vendor-recommended values for 10KHz/100KHz/400KHz.

This is still a work-in-progress, but currently can draw individual pixels, rectangle outlines or fills, and some basic text. It is not complete or pretty, though; I still have to clean up some functions and work out the weirdness of how the framebuffer memory has to be set up. Or see if I can use a different memory mode, maybe? Right now, each byte seems to write 8 *vertical* bits, before shifting 1 pixel *horizontally.* Kinda inconvenient, yeah?

Anyways, the test 'main' method draws a smiley face, a couple of rectangles, and a 'Hello'. Letters other than 'H', 'e', 'l', and 'o' will probably appear mangled; I messed up some endian-ness when initially transcribing them...

And I'm not sure if this is part of the driver IC specification or just something on the cheap 4-pin breakout boards, but this also assumes that the screen has an internal charge pump, meaning that the - what, 6-15V? - display bias voltage is generated internally and we only need to give the screen +VCC (3.3V-5V? I use 3.3V), GND, SCL, and SDA.
