`timescale 1ns/1ps

module dual_timePulser #(
    parameter int unsigned NUM_CHANNELS = 10,
    parameter int unsigned DELAY_CYCLES = 10 // 10 cycles of 200MHz = 50ns base
)(
    input  logic clk_base,     // 200 MHz (0 deg)
    input  logic clk_shifted,  // 200 MHz (Variable Phase)
    input  logic n_rst,
    input  logic trigger,
    
    output logic [NUM_CHANNELS-1:0] pulse
);

    // --- Domain Synchronization ---
    // A trigger in the 100MHz domain must be safely passed into BOTH 200MHz domains
    logic trig_sync_base_1, trig_sync_base_2;
    logic trig_sync_shift_1, trig_sync_shift_2;
    
    always_ff @(posedge clk_base) 
        {trig_sync_base_2, trig_sync_base_1} <= {trig_sync_base_1, trigger};
        
    always_ff @(posedge clk_shifted) 
        {trig_sync_shift_2, trig_sync_shift_1} <= {trig_sync_shift_1, trigger};

    // --- Arrays for 1-cycle SET and RESET pulses ---
    logic [NUM_CHANNELS-1:0] set_pulses;
    logic [NUM_CHANNELS-1:0] reset_pulses;

    // --- clk_base Domain: Generates the SET pulses ---
    int base_count;
    int base_channel;
    logic base_active;

    always_ff @(posedge clk_base or negedge n_rst) begin
        if (!n_rst) begin
            base_count <= 0;
            base_channel <= 0;
            base_active <= 0;
            set_pulses <= '0;
        end else begin
            set_pulses <= '0; // Default to 0
            
            if (!base_active && trig_sync_base_2) begin
                base_active <= 1;
                base_count <= 0;
                base_channel <= 0;
            end else if (base_active) begin
                if (base_count == 0) set_pulses[base_channel] <= 1'b1;
                
                if (base_count >= DELAY_CYCLES - 1) begin
                    base_count <= 0;
                    if (base_channel == NUM_CHANNELS - 1)
                        base_active <= 0;
                    else
                        base_channel <= base_channel + 1;
                end else begin
                    base_count <= base_count + 1;
                end
            end
        end
    end

    // --- clk_shifted Domain: Generates the RESET pulses ---
    int shift_count;
    int shift_channel;
    logic shift_active;

    always_ff @(posedge clk_shifted or negedge n_rst) begin
        if (!n_rst) begin
            shift_count <= 0;
            shift_channel <= 0;
            shift_active <= 0;
            reset_pulses <= '0;
        end else begin
            reset_pulses <= '0; // Default to 0
            
            if (!shift_active && trig_sync_shift_2) begin
                shift_active <= 1;
                shift_count <= 0;
                shift_channel <= 0;
            end else if (shift_active) begin
                // The RESET pulse fires at the END of the 10-cycle window
                if (shift_count == DELAY_CYCLES - 1) reset_pulses[shift_channel] <= 1'b1;
                
                if (shift_count >= DELAY_CYCLES - 1) begin
                    shift_count <= 0;
                    if (shift_channel == NUM_CHANNELS - 1)
                        shift_active <= 0;
                    else
                        shift_channel <= shift_channel + 1;
                end else begin
                    shift_count <= shift_count + 1;
                end
            end
        end
    end

    // --- The Asynchronous SR Latches ---
    // This DONT_TOUCH attribute is MANDATORY. It stops Vivado from optimizing 
    // these cross-clock combinational loops into standard flip-flops.
    (* DONT_TOUCH = "TRUE" *) logic [NUM_CHANNELS-1:0] final_pulses;

    always_latch begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            if (reset_pulses[i]) 
                final_pulses[i] <= 1'b0;
            else if (set_pulses[i]) 
                final_pulses[i] <= 1'b1;
        end
    end

    assign pulse = final_pulses;

endmodule