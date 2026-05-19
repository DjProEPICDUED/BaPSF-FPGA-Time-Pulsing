5/18:
Project introduced: need a pulser that triggers 10 segments of copper core sections wrapped in nylon wire that generate 1kV each one after the other for 50ns to generate total of 10kV for plasma measurement. Program needs to be triggered by a 10 ns input pulse. 

Made program that generates 50ns pulses for 10 separate output channels. Added feature where flicking a switch will add or remove 5ns from the 50 ns pulse for fine tunning and testing as the copper cores might not actually have 50 ns long pulses. 

Got successful waveforms in Vivado. 

5/19:
Added a push button input for testing program without needing 10ns input pulse. Added LEDs with different colors to indicate different modes. Created .xdc file for pins and buttons on Arty A7 100T dev board. Successfuly synthesised the code onto the Arty A7. 

New challenge, 50ns with +-5ns isn't enough. Need to be able to tweak the 50ns pulse by minimum of 1ns (best if in ps range). Boosting clk higher (it's already at 200 MHz) won't fix the issue. Two options MMCM or CARRY4 Delay method. Settled on MMCM due to high reliability and ability to tweak at very small time scales (theoretically 17.8 ps).

