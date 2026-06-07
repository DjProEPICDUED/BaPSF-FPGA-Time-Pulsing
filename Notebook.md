### 5/21:
Did some additional testing with the oscilloscope and wavegen in the morning and found an issue
An idea off the top of my head was, have like 5 clks all going at different phases and the first clk to detect the trigger becomes the pulse clock and the rest are ignored. Another idea is to calculate how early the trigger is using TDC then generate a clk that has a phase that compensates for the early trigger using MMCM. 
From researching the problem a couple methods are: 
  ISERDES/OSERDES: A hyper fast ring counter + sampling on posedge and negedge. 
  time-to-digital converter measure how early or late the trigger came in, then use combinational carry4s to compensate for known delay or use ODELAY2 to take into account that delay. Problem is TDC is not temperature calibrated but ODELAY2 is. This should be fine as at worst at high temperatures there should be around a 0.3 ns difference which is within the 1 ns goal tolerance. 
  Use a faster clock (500 MHz would give 2 ns period which should be around $$\pm$$ 1 ns error)

After some discussion, it was determined for it to be easier for the FPGA to acts the global trigger for the laser, high speed camera, and other equipment in the lab. The FPGA needs to provide 5 triggers with a 10 ms pulse at 3.3 V. 

This simplifies the problem much more. Now the delay between the trigger and first pulse is always the same and I added outputs from the FPGA to trigger all the other peripherals in the lab. 

### 5/20:
Ran simulation in Vivado and got a lot of errors. When one is solved, another appears in its place. Codex deep code review found many critical errors caused primarily by using two different clock domains. Two paths remain: fix the issues and keep using the MMCM dual-clock-domain method, or switch to a single-clock ODELAY/OSERDES method. The MMCM approach might require manual placement of SR latches in the FPGA fabric. ODELAY could change the 50 ns pulse by about ±78.1 ps.

After researching the issue, ODELAY and OSERDES are not valid implementations for this design because they delay the entire clock rather than change individual pulses or pulse width. There is a much simpler solution that I didn't think was possible on the Arty A7 100T: dynamically reconfigurable fractional clocks.

$$F_{\text{out}} = \frac{F_{\text{in}} \times M}{D \times O}$$

The design uses MMCM IP with dynamic frequency enabled. It uses code provided by AMD to compute the frequency settings during synthesis and save the data in ROM. The system allows the user to shift the 50 ns pulse timing in 0.5 ns steps between 45 ns and 55 ns. It uses a lot of clock-domain synchronization to keep signal integrity and avoid metastability.

I used an oscilloscope to physically test the board. It is able to generate reliable and clean nanosecond pulses, and the increments/decrements work successfully. There is a 176 ns delay between the trigger pulse and the first output pulse. This is okay as long as the delay is constant and repeatable.

### 5/19:
Added a pushbutton input for testing the design without needing a 10 ns input pulse. Added LEDs with different colors to indicate different modes. Created an .xdc file for pins and buttons on the Arty A7 100T dev board. Successfully synthesized the code onto the Arty A7.

New challenge: 50 ns ±5 ns isn't enough. I need to be able to tweak the 50 ns pulse by a minimum of 1 ns (best if in the picosecond range). Boosting the clock higher (it's already at 200 MHz) won't fix the issue. Two options remained: MMCM or CARRY4 delay. I settled on MMCM due to higher reliability and the ability to tune at very small time scales (theoretically about 17.8 ps).

### 5/18:
Project introduced: need a pulser that triggers 10 copper-core sections wrapped in nylon wire, each generating about 1 kV sequentially for 50 ns, producing a total of 10 kV for plasma measurement. The design needs to be triggered by a 10 ns input pulse.

Made a design that generates 50 ns pulses for 10 separate output channels. Added a feature where flicking a switch will add or remove 5 ns from the 50 ns pulse for fine tuning and testing, because the copper cores might not actually require exactly 50 ns pulses.
Got successful waveforms in Vivado. 
