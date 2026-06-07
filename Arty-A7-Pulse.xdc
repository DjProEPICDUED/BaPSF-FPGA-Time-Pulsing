## Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];

## Buttons (rst) btn 0
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { rst }];
## External Trigger Button (btn 1) 
set_property -dict { PACKAGE_PIN C9    IOSTANDARD LVCMOS33 } [get_ports { ext_btn_signal }]; 
set_property -dict { PACKAGE_PIN B9    IOSTANDARD LVCMOS33 } [get_ports { btn_add_time }];
set_property -dict { PACKAGE_PIN B8    IOSTANDARD LVCMOS33 } [get_ports { btn_sub_time }];

## -----------------------------------------------------------------------------
## High-Speed Pmod JB 
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[0] }]; 
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[1] }]; 
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[2] }]; 
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[3] }]; 
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[4] }]; 
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[5] }]; 
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[6] }]; 

## -----------------------------------------------------------------------------
## High-Speed Pmod JC (Using all 8 pins for outputs 0 through 7)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[7] }]; 
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[8] }]; 
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[9] }]; 
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[10] }]; 
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[11] }]; 
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[12] }]; 
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[13] }]; 
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { output_pulse[14] }];

## -----------------------------------------------------------------------------
## Outputs For the output triggers
## -----------------------------------------------------------------------------
#3 IO 0 - IO4
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { triggerOut1  }]; 
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { triggerOut2  }]; 
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { triggerOut3  }]; 
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { triggerOut4  }]; 
set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { triggerOut5  }]; 

##-----------------------------------------
## RGB LED (LD4)
##-----------------------------------------
set_property -dict { PACKAGE_PIN G6   IOSTANDARD LVCMOS33 } [get_ports { led4_r }]; # Red channel
set_property -dict { PACKAGE_PIN F6   IOSTANDARD LVCMOS33 } [get_ports { led4_g }]; # Green channel
set_property -dict { PACKAGE_PIN E1   IOSTANDARD LVCMOS33 } [get_ports { led4_b }]; # Blue channel

## LEDs (Useful to verify the clock wizard is locked)
set_property -dict { PACKAGE_PIN T10    IOSTANDARD LVCMOS33 } [get_ports { locked }];