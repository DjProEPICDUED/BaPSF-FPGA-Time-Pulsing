# BaPSF-FPGA-Time-Pulsing

We’re building a high-speed multi-channel pulse propagation system using an Arty A7-100T FPGA to generate precisely timed pulses (around 50 ns) that sequentially switch MOSFET-driven coils/channels. The project focuses on achieving extremely accurate inter-channel timing and understanding propagation effects, transmission-line behavior, and hardware limitations using techniques like MMCMs, delay lines, and phase-shifted clocks.



Project Notes / Dump:

https://docs.amd.com/r/en-US/ug572-ultrascale-clocking/Clocking-Overview

Technique,Max Resolution,Complexity,PVT Stability
MMCM Dynamic Phase,< 0.1 ns,High (Requires LUT latching & cross-clock care),Excellent (MMCM compensates for temperature)
OSERDESE2,1.0 ns,Medium (Requires data formatting logic),Excellent (Fully synchronous)
CARRY4 Delay,~0.1 ns,Low (Simple logic implementation),Poor (Drifts with temperature)