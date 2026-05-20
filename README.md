# BaPSF-FPGA-Time-Pulsing

We’re building a high-speed multi-channel pulse propagation system using an Arty A7-100T FPGA to generate precisely timed pulses (around 50 ns) that sequentially switch MOSFET-driven coils/channels. The project focuses on achieving extremely accurate inter-channel timing and understanding propagation effects, transmission-line behavior, and hardware limitations using techniques like MMCMs, delay lines, and phase-shifted clocks. The user has the ability to change the length of the pulse by plus minus 0.5 ns by pressing buttons on the FPGA dev board. (e.g. change the pulse width from 50ns to 50.5 ns). This is done using MMCM where two clk domains are phase shifted and one is the posedge of the pulse and the ohter is the negedge. 



Project Notes / Dump:

https://docs.amd.com/r/en-US/ug572-ultrascale-clocking/Clocking-Overview

Technique,Max Resolution,Complexity,PVT Stability
MMCM Dynamic Phase,< 0.1 ns,High (Requires LUT latching & cross-clock care),Excellent (MMCM compensates for temperature)
OSERDESE2,1.0 ns,Medium (Requires data formatting logic),Excellent (Fully synchronous)
CARRY4 Delay,~0.1 ns,Low (Simple logic implementation),Poor (Drifts with temperature)