module top (
    input wire clk_100mhz,
    input logic n_rst,   
    input logic trigger,
    input logic add5ns,
    input logic sub5ns,
    output logic [9:0] output_pulse,
    output logic locked     
);

    wire clk_200mhz;

    clk_wiz_0 clk_multiplier (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_200mhz),
        .resetn(n_rst), 
        .locked(locked)  
    );

    timePulser #(
        .NUM_CHANNELS(10),
        .DELAY(50) 
    ) pulser (
        .clk(clk_200mhz),
        .n_rst(n_rst),
        .ten_ns_input(trigger & locked),
        .add5ns(add5ns),         
        .sub5ns(sub5ns),        
        .pulse(output_pulse)             
    );

endmodule