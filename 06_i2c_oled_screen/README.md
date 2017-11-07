# Overview

Interface with an SSD1306 OLED screen over simple SDA/SCL I2C interface.

NOTE: While STM32F303 linker/boot/etc files are present, this will almost certainly only work with the STM32F030 - and maybe only the 20-pin package. You'll probably need to adjust the pin numbers, Alternate Function modes, etc for other chips. Refer to their datasheets for the appropriate values. Also, the TIMINGR register value is set up for 100KHz 'standard mode' I2C speed on a 48MHz peripheral clock. I'm sure 400KHz would work fine, but I'm not super concerned with performance at this moment and 100KHz is easier to catch on a scope.

This is very much a work-in-progress; currently it just writes a blank screen of '1's, turning all of the monochrome pixels on. But it does that after initializing the screen with a variety of I2C commands, so I think it's not a bad 'hello world' commit.

There's no framebuffer or anything, but at least this is a working minimal example for a 128x64 pixel SSD1306-driven OLED screen.

And I'm not sure if this is part of the driver IC specification or just something on the cheap 4-pin breakout boards, but this also assumes that the screen has an internal charge pump, meaning that the - what, 6-15V? - display bias voltage is generated internally and we only need to give the screen +VCC (3.3V-5V? I use 3.3V), GND, SCL, and SDA.

So I'll probably add stuff like a framebuffer in RAM and drawing functions soon, but this is a simple starting point.
