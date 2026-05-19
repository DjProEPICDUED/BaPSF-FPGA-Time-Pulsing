module top (
    input wire clk_100mhz,
    input logic rst,   
    input logic trigger,
    input logic ext_btn_signal,
    input logic add5ns,
    input logic sub5ns,
    output logic [9:0] output_pulse,
    output logic locked,   

    output logic led4_r,
    output logic led4_g,
    output logic led4_b  
);

    logic n_rst;
    assign n_rst = ~rst;

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
        .ten_ns_input((trigger | ext_btn_signal) & locked),
        .add5ns(add5ns),         
        .sub5ns(sub5ns),        
        .pulse(output_pulse)             
    );

    always_comb begin
        // Default everything to off
        led4_r = 1'b0;
        led4_g = 1'b0;
        led4_b = 1'b0;

        if (sub5ns) begin
            led4_r = 1'b1; // Red when sub5 is enabled
        end else if (add5ns) begin
            led4_g = 1'b1; // Green when add5 is enabled
        end else begin
            led4_b = 1'b1; // Blue when neither switch/button is active
        end
    end

endmodule