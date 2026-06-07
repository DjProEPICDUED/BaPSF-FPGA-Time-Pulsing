`timescale 1ns/1ps

module timePulse #(
    parameter int unsigned NUM_CHANNELS = 15
)(
    input  logic clk_var,       
    input  logic n_rst,         
    input  logic trigger_sync,  
    
    output logic [NUM_CHANNELS - 1:0] pulse
);

    logic active;
    logic [$clog2(NUM_CHANNELS)-1:0] channel_idx;
    logic trigger_seen;

    always_ff @(posedge clk_var or negedge n_rst) begin
        if (!n_rst) begin
            active       <= 1'b0;
            channel_idx  <= '0;
            pulse        <= '0;
            trigger_seen <= 1'b0;
        end else begin
            pulse <= '0;

            if (!active) begin
                channel_idx <= '0;
                
                // Require the trigger to go low before re-arming
                if (!trigger_sync) trigger_seen <= 1'b0;
                
                // Only fire if the trigger goes high AND we haven't already processed it
                if (trigger_sync && !trigger_seen) begin
                    trigger_seen <= 1'b1;
                    active       <= 1'b1;
                    pulse[0]     <= 1'b1; // Fire channel 0 immediately
                end
                
            end else begin
                // Shift to the next channel every clock cycle
                if (channel_idx == NUM_CHANNELS - 1) begin
                    active <= 1'b0; // Sequence complete
                end else begin
                    channel_idx <= channel_idx + 1;
                    pulse[channel_idx + 1] <= 1'b1;
                end
            end
        end
    end

endmodule