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

    JC PMOD (2rd from the left on the side of dev board) Using all 8 pins for outputs 7 through 14
    JB PMOD (3rd from the left on the side of dev board) Using 7 pins for outputs 0 through 6

## PCB:
![3D PCB Render](img/PCBrendTop.png)

    This custom PCB plugs into the Arty A7's PMOD headers and allows the signal to rapidly trigger powerful MOSFETs. The PCB is a 4 layer PCB that takes 15 inputs from an Arty A7's PMOD connectors, and via length and impedance matched traces, passes the signal through 15 gate drivers. The gate drivers boost the signal and (through 4 200 ohm resistors in parallel (for 50 ohms)) output it to their respective SMA connector. 


## Purpose:
FPGA needs to trigger 10 copper cores acting as transmission lines one after the other, providing each with around a 50 ns pulse.
Overall, the project will be used to measure the strength of electric fields using Stark Spectroscopy in the LAM processing lab at the BaPSF. 

Used for a high-speed multi-channel pulse propagation system using an Arty A7-100T FPGA to generate precisely timed pulses (around 50 ns) that sequentially switch MOSFET-driven coils/channels. User can change pulse in range of 45 - 55 ns in 0.5 ns increments / decrements. The FPGA is able to trigger other equipment in the lab

