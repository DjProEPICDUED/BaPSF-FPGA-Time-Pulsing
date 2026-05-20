module mmcm_shifter (
    input  logic clk_100mhz, // psclk must run on the base board clock
    input  logic n_rst,
    input  logic btn_add_half_ns,
    input  logic btn_sub_half_ns,
    
    // Interface to clk_wiz_0
    output logic psen,
    output logic psincdec,
    input  logic psdone
);

    localparam int SHIFTS_NEEDED = 28; // 28 steps * ~17.85ps = ~0.5ns
    
    typedef enum logic [2:0] {IDLE, TRIGGER, WAIT_DONE, CHECK_COUNT} state_t;
    state_t state;
    
    int shift_count;

    // Edge detectors for buttons (assumes external debouncing)
    logic btn_add_d, btn_sub_d;
    logic start_add, start_sub;

    always_ff @(posedge clk_100mhz or negedge n_rst) begin
        if (!n_rst) begin
            btn_add_d <= 0;
            btn_sub_d <= 0;
            state <= IDLE;
            psen <= 0;
            psincdec <= 0;
            shift_count <= 0;
        end else begin
            btn_add_d <= btn_add_half_ns;
            btn_sub_d <= btn_sub_half_ns;

            case (state)
                IDLE: begin
                    psen <= 0;
                    shift_count <= 0;
                    if (start_add) begin
                        psincdec <= 1; // 1 = Increment phase
                        state <= TRIGGER;
                    end else if (start_sub) begin
                        psincdec <= 0; // 0 = Decrement phase
                        state <= TRIGGER;
                    end
                end
                
                TRIGGER: begin
                    psen <= 1; // Assert PSEN for exactly 1 cycle
                    state <= WAIT_DONE;
                end
                
                WAIT_DONE: begin
                    psen <= 0;
                    if (psdone) begin // Wait for MMCM to confirm shift
                        shift_count <= shift_count + 1;
                        state <= CHECK_COUNT;
                    end
                end
                
                CHECK_COUNT: begin
                    if (shift_count >= SHIFTS_NEEDED)
                        state <= IDLE;
                    else
                        state <= TRIGGER; // Loop until 28 shifts are done
                end
            endcase
        end
    end

    always_comb begin
        start_add = btn_add_half_ns && !btn_add_d;
        start_sub = btn_sub_half_ns && !btn_sub_d;
    end

endmodule