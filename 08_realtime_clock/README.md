# Overview

This is a simple example to initialize the STM32's RTC (RealTime Clock) peripheral. It doesn't do any alarm/timer/etc stuff, just turns the clock on using the internal LSI oscillator. It also sets the timing presacalers to their minimum values, to cycle the 'subsecond' register as quickly as possible.

Basically this is a quick and dirty way to generate pseudo-random numbers for applications where the random-ness doesn't matter too much. Once the clock is on, just read the 'RTC\_SS' register to get a pseudo-random value between...uh, I duno, I guess probably 0 and 255 or so? I'm still coming to grips with this peripheral.

Anyways, using the LSI oscillator here has two benefits. One, it is not very precise compared to an external crystal oscillator. I think that's better for pseudo-random number generation, even if it's not ideal for keeping time. And two, it is inside of the chip. Some very small packages, like the STM32F030F4 I'm using, don't break out LSE pins so a low-speed external oscillator is simply not available. And ditto for some of ST's Nucleo boards, which don't even include an external HSE crystal!
