# BaPSF FPGA Pulse Propagation System

High-speed FPGA-based pulse generation system for Stark spectroscopy experiments at the Basic Plasma Science Facility (BaPSF).

Built on the Arty A7-100T FPGA, the system generates precisely timed nanosecond pulses across 10 output channels for synchronized triggering and pulse propagation experiments.

Features:
- 10 synchronized output channels
- Adjustable pulse width from 45–55 ns
- 0.5 ns timing resolution
- Hardware-tested on oscilloscope
- FPGA-generated global trigger outputs
- MMCM-based dynamic timing control

## How To Use:
On the Arty A7 100T dev board:

![Top View](img/topView.png)

    BTN 0: Reset
    BTN 1: Trigger
    BTN 2: Increase 50 ns default pulse up by 0.5 ns (Max 55 ns pulse)
    BTN 3: Decrease 50 ns default pulse up by 0.5 ns (Min 45 ns pulse)
    IO 0 - IO 4 (Number 10 in the image): Outputs for the external triggers (laszers, high speed camera, etc ..) 

![PMOD Side View](img/pmodSide.png)

    JC PMOD (2nd from the left on the side of dev board) Using all 8 pins for outputs 0 through 7
    JB PMOD (3rd from the left on the side of dev board) Pins 1 & 2 used for outputs 8 & 9

## Technical Highlights

- Verilog/SystemVerilog FPGA design
- Multi-channel pulse sequencing
- MMCM dynamic clock reconfiguration
- Clock-domain synchronization
- Metastability mitigation
- Timing-critical digital design
- Vivado simulation and synthesis
- Oscilloscope-based hardware validation
- Xilinx Artix-7 FPGA development
- Constraint management with XDC

![Waveforms Showing Program Running As Intended](img/Waveforms.png)

![Pic of oscilloscope showing first pulse and triggers all starting on the same posedge](img/oscilloscope.jpeg)


