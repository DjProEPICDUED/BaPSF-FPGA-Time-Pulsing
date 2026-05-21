# BaPSF-FPGA-Time-Pulsing-Project

## How To Use:
On the Arty A7 100T dev board:

![Top View](img/topView.png)

    BTN 0: Reset
    BTN 1: Trigger
    BTN 2: Increase 50 ns defualt pulse up by 0.5 ns (Max 55 ns pulse)
    BTN 3: Decrease 50 ns defualt pulse up by 0.5 ns (Min 45 ns pulse)
    IO 0 - IO 4 (Number 10 in the image): Outputs for the external triggers (laszers, high speed camera, etc ..) 

![PMOD Side View](img/pmodSide.png)

    JC PMOD (2rd from the left on the side of dev board) Using all 8 pins for outputs 0 through 7
    JB PMOD (3rd from the left on the side of dev board) Pins 1 & 2 used for outputs 8 & 9

## Purpose:
FPGA needs to trigger 10 copper cores acting as transmission lines one after the other, providing each with around a 50 ns pulse.
Overall, the project will be used to measure the strength of the electric field using Stark Spectroscopy in the LAM processing lab at the BaPSF. 

Used for a high-speed multi-channel pulse propagation system using an Arty A7-100T FPGA to generate precisely timed pulses (around 50 ns) that sequentially switch MOSFET-driven coils/channels. User can change pulse in range of 45 - 55 ns in 0.5 ns increments / decrements.

