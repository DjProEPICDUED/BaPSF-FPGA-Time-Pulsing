`timescale 1ns/1ps

module top (
    input  wire  clk_100mhz,
    input  logic rst,   
    input  logic trigger,
    input  logic ext_btn_signal,
    
    // Repurposing these for the 0.5ns MMCM adjustments
    input  logic btn_add_half_ns, // e.g., BTN2
    input  logic btn_sub_half_ns, // e.g., BTN3
    
    output logic [9:0] output_pulse,
    output logic locked,   

    output logic led4_r,
    output logic led4_g,
    output logic led4_b  
);

    logic n_rst;
    assign n_rst = ~rst;

    wire clk_base_200mhz;
    wire clk_shifted_200mhz;
    
    // MMCM Dynamic Phase Shift Interface wires
    wire psen, psincdec, psdone;

    //clk_wiz_0_clk_wiz clk_multiplier (
    clk_wiz_0 clk_multiplier (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_base_200mhz),     // 200 MHz, 0 phase shift
        .clk_out2(clk_shifted_200mhz),  // 200 MHz, Variable phase shift
        
        // Dynamic phase shift ports
        .psclk(clk_100mhz), 
        .psen(psen),
        .psincdec(psincdec),
        .psdone(psdone),
        
        // Status and control signals
        .reset(rst),      
        .locked(locked)  
    );

    // The state machine that steps the MMCM 28 times per button press
    mmcm_shifter phase_controller (
        .clk_100mhz(clk_100mhz),
        .n_rst(n_rst),
        .btn_add_half_ns(btn_add_half_ns),
        .btn_sub_half_ns(btn_sub_half_ns),

        .psen(psen),
        .psincdec(psincdec),
        .psdone(psdone)
    );

    // pulse generator
    dual_timePulser #(
        .NUM_CHANNELS(10),
        .DELAY_CYCLES(10) // 10 cycles = 50ns
    ) pulser (
        .clk_base(clk_base_200mhz),
        .clk_shifted(clk_shifted_200mhz),
        .n_rst(n_rst),
        .trigger((trigger | ext_btn_signal) & locked),

        .pulse(output_pulse)
    );

    // LED logic to visualize the state
    always_comb begin
        led4_r = btn_sub_half_ns; // Red when subtracting time
        led4_g = btn_add_half_ns; // Green when adding time
        led4_b = locked;          // Blue when MMCM is stable
    end

endmodule