# BaPSF-FPGA-Time-Pulsing

We’re building a high-speed multi-channel pulse propagation system using an Arty A7-100T FPGA to generate precisely timed pulses (around 50 ns) that sequentially switch MOSFET-driven coils/channels. The project focuses on achieving extremely accurate inter-channel timing and understanding propagation effects, transmission-line behavior, and hardware limitations using techniques like MMCMs, delay lines, and phase-shifted clocks.

FPGA needs to trigger 10 copper cores acting as transmission lines one after the other, providing each with around a 50 ns pulse.
Overall, the project will be used to measure the strength of the electric field using Stark Spectroscopy in the LAM applications lab at the BaPSF. 


Project Notes / Dump:

https://docs.amd.com/r/en-US/ug572-ultrascale-clocking/Clocking-Overview

Technique,Max Resolution,Complexity,PVT Stability
MMCM Dynamic Phase,< 0.1 ns,High (Requires LUT latching & cross-clock care),Excellent (MMCM compensates for temperature)
OSERDESE2,1.0 ns,Medium (Requires data formatting logic),Excellent (Fully synchronous)
CARRY4 Delay,~0.1 ns,Low (Simple logic implementation),Poor (Drifts with temperature)
