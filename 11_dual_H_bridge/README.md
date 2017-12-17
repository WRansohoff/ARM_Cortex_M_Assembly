#overview

This is a simple program which accepts 4 button inputs to drive 2 motors in 2 directions through a dual H-bridge circuit like an L293D. While that particular chip requires a supply voltage of at least 4.5V, its 'logic high' level is anywhere between 2.3V-7V which means that the 3.3V microcontroller should be able to drive it without level shifting as long as 5V power is available, like from USB.

Just, be careful about how much current you draw driving motors from a USB port. The L293D is only rated to 600mA, so that'll probably be okay if you don't push it. Four AA or AAA batteries is another good idea - rechargeable ones will be about 4.8V nominal, alkaline about 6V.
