// Assume clk is 200 MHz (Period = 5 ns)
module timePulser #(
    parameter int unsigned NUM_CHANNELS = 10, // number of output channels
    parameter int unsigned DELAY = 50    
)(
    input  logic clk,
    input  logic n_rst,
    input  logic ten_ns_input,
    input  logic add5ns, // 1 if need to add 5ns to DELAY
    input  logic sub5ns, // 1 if need to remove 5ns to DELAY
    output logic [NUM_CHANNELS - 1:0] pulse
);

    localparam int unsigned CLK_NS = 5;
    localparam int unsigned CH_W = (NUM_CHANNELS <= 1) ? 1 : $clog2(NUM_CHANNELS);
    
    // Calculate base cycles at compile-time to avoid runtime division
    localparam int unsigned BASE_CYCLES = DELAY / CLK_NS;

    logic ten_ns_input_d;
    logic active;
    logic [CH_W - 1:0] channel_idx;
    int unsigned count;
    int unsigned delay_cycles;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            ten_ns_input_d <= 1'b0;
            active         <= 1'b0;
            channel_idx    <= '0;
            count          <= 0;
            delay_cycles   <= BASE_CYCLES;
        end else begin
            ten_ns_input_d <= ten_ns_input;

            if (!active) begin
                count <= 0;
                channel_idx <= '0;
                
                if (ten_ns_input && !ten_ns_input_d) begin
                    active <= 1'b1;
                    
                    if (add5ns && !sub5ns) begin
                        delay_cycles <= BASE_CYCLES + 1;
                    end else if (sub5ns && !add5ns && BASE_CYCLES > 1) begin
                        delay_cycles <= BASE_CYCLES - 1; 
                    end else begin
                        delay_cycles <= BASE_CYCLES;  
                    end
                end
            end else begin
                if (count >= (delay_cycles - 1)) begin
                    count <= 0;
                    if (channel_idx == (NUM_CHANNELS - 1)) begin
                        active <= 1'b0; 
                    end else begin
                        channel_idx <= channel_idx + 1'b1; 
                    end
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end

    always_comb begin
        pulse = '0;
        if (active) begin
            pulse[channel_idx] = 1'b1;
        end
    end

endmodule