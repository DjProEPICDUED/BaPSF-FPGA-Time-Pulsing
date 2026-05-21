`timescale 1ns/1ps

module top (
    input  wire  clk_100mhz,
    input  logic rst,   
    input  logic ext_btn_signal,
    
    // Buttons to change frequency (pulse width)
    input  logic btn_add_time, // Sweeps towards 55.0 ns
    input  logic btn_sub_time, // Sweeps towards 45.0 ns
    
    output logic [9:0] output_pulse,
    output logic locked,   

    output logic triggerOut1,
    output logic triggerOut2,
    output logic triggerOut3,
    output logic triggerOut4,
    output logic triggerOut5,

    output logic led4_r,
    output logic led4_g,
    output logic led4_b  
);

    wire clk_var_20mhz; // The dynamically shifting clock

    // Reset Synchronizers
    (* ASYNC_REG = "TRUE" *) logic [1:0] rst_100_sync, rst_var_sync;
    
    always_ff @(posedge clk_100mhz or posedge rst) begin
        if (rst) rst_100_sync <= 2'b00;
        else rst_100_sync <= {rst_100_sync[0], 1'b1}; 
    end

    always_ff @(posedge clk_var_20mhz or posedge rst) begin
        if (rst) rst_var_sync <= 2'b00;
        else rst_var_sync <= {rst_var_sync[0], 1'b1};
    end

    wire n_rst_100 = rst_100_sync[1];
    wire n_rst_var = rst_var_sync[1];

    // DRP FSM reset: fully synchronous to clk_100mhz
    logic [1:0] rst_100_full_sync;
    always_ff @(posedge clk_100mhz) begin
        rst_100_full_sync <= {rst_100_full_sync[0], rst};
    end
    wire rst_drp_fsm = rst_100_full_sync[1];

    // Synchronize LOCKED into clk_100mhz for DRP control gating
    (* ASYNC_REG = "TRUE" *) logic [1:0] locked_100_sync;
    always_ff @(posedge clk_100mhz or negedge n_rst_100) begin
        if (!n_rst_100) locked_100_sync <= 2'b00;
        else            locked_100_sync <= {locked_100_sync[0], locked};
    end
    wire locked_100 = locked_100_sync[1];
    
    // --- DRP Bus Wires ---
    wire [6:0]  daddr;
    wire        den;
    wire [15:0] di;
    wire [15:0] dout;
    wire        drdy;
    wire        dwe;
    
    // --- DRP Control Wires ---
    logic       drp_sen;    
    logic [4:0] drp_saddr;  
    wire        drp_srdy;   
    wire        drp_rst_mmcm; 

    wire mmcm_combined_resetn = n_rst_100 & ~drp_rst_mmcm;

    // MMCM Instantiation
    clk_wiz_0 clk_multiplier (
        .clk_in1 (clk_100mhz),
        .clk_out1(clk_var_20mhz),
        
        .daddr   (daddr),
        .dclk    (clk_100mhz),
        .den     (den),
        .din     (di),
        .dout    (dout),
        .drdy    (drdy),
        .dwe     (dwe),
        
        .resetn  (mmcm_combined_resetn), 
        .locked  (locked)  
    );

    // XAPP888 DRP Controller Instantiation
    mmcme2_drp drp_controller (
        .SADDR           (drp_saddr), 
        .SEN             (drp_sen),
        .RST             (rst_drp_fsm),
        .SRDY            (drp_srdy),
        
        .SCLK            (clk_100mhz),
        .DO              (dout),
        .DRDY            (drdy),
        .DWE             (dwe),
        .DEN             (den),
        .DADDR           (daddr),
        .DI              (di),
        .DCLK            (),
        .RST_MMCM        (drp_rst_mmcm),  
        .LOCKED_IN       (locked),     
        .LOCK_REG_CLK_IN (clk_100mhz), 
        .LOCKED_OUT      ()            
    );

    // Button Synchronizers & Buffered DRP State Machine
    (* ASYNC_REG = "TRUE" *) logic [1:0] sync_add, sync_sub;
    
    always_ff @(posedge clk_100mhz or negedge n_rst_100) begin
        if (!n_rst_100) begin
            sync_add <= 2'b00;
            sync_sub <= 2'b00;
        end else begin
            sync_add <= {sync_add[0], btn_add_time};
            sync_sub <= {sync_sub[0], btn_sub_time};
        end
    end
    
    logic add_edge, sub_edge;
    assign add_edge = sync_add[1] & ~sync_add[0];
    assign sub_edge = sync_sub[1] & ~sync_sub[0];

    localparam int MAX_STATE  = 20; // Index 20 = 55.0ns
    localparam int BASE_STATE = 10; // Index 10 = 50.0ns Base

    logic [4:0] drp_saddr_next;
    logic drp_req;

    always_ff @(posedge clk_100mhz or negedge n_rst_100) begin
        if (!n_rst_100) begin
            drp_saddr      <= BASE_STATE;
            drp_saddr_next <= BASE_STATE;
            drp_sen        <= 1'b0;
            drp_req        <= 1'b0; // Initial config on startup
        end else begin
            drp_sen <= 1'b0;

            if (drp_req) begin
                if (drp_is_ready && locked_100) begin 
                    drp_saddr <= drp_saddr_next;
                    drp_sen   <= 1'b1;
                    drp_req   <= 1'b0;
                end
            end else if (drp_is_ready && locked_100) begin
                if (add_edge && (drp_saddr < MAX_STATE)) begin
                    drp_saddr_next <= drp_saddr + 1'b1;
                    drp_req        <= 1'b1;
                end else if (sub_edge && (drp_saddr > 0)) begin
                    drp_saddr_next <= drp_saddr - 1'b1;
                    drp_req        <= 1'b1;
                end
            end
        end
    end

    logic drp_is_ready;
    always_ff @(posedge clk_100mhz or negedge n_rst_100) begin
        if (!n_rst_100) begin
            drp_is_ready <= 1'b0;
        end else begin
            if (drp_srdy) begin
                drp_is_ready <= 1'b1;  // Latch high when MMCM is locked and ready
            end else if (drp_sen) begin
                drp_is_ready <= 1'b0;  // Drops low while reconfiguring
            end
        end
    end

    // Status Signal CDC
    // Synchronize MMCM status signals into the variable domain before gating
    (* ASYNC_REG = "TRUE" *) logic [1:0] locked_sync, srdy_sync;

    always_ff @(posedge clk_var_20mhz or negedge n_rst_var) begin
        if (!n_rst_var) begin
            locked_sync <= 2'b00;
            srdy_sync   <= 2'b00;
        end else begin
            locked_sync <= {locked_sync[0], locked};
            srdy_sync   <= {srdy_sync[0], drp_is_ready};
        end
    end

    wire locked_var = locked_sync[1];
    wire srdy_var = srdy_sync[1];

    // External button synchronizer and deterministic trigger generation
    (* ASYNC_REG = "TRUE" *) logic [1:0] btn_sync;
    logic btn_sync_d;

    localparam int unsigned TRIG_HOLD_CYCLES = 200_000; // ~10 ms at 20 MHz
    localparam int unsigned TRIG_HOLD_WIDTH  = $clog2(TRIG_HOLD_CYCLES + 1);

    logic [TRIG_HOLD_WIDTH-1:0] trig_hold_cnt;
    logic trigger_out_active;

    wire trigger_edge = btn_sync[1] & ~btn_sync_d;
    wire trigger_fire = trigger_edge & locked_var & srdy_var;

    always_ff @(posedge clk_var_20mhz or negedge n_rst_var) begin
        if (!n_rst_var) begin
            btn_sync           <= 2'b00;
            btn_sync_d         <= 1'b0;
            trigger_out_active <= 1'b0;
            trig_hold_cnt      <= '0;
        end else begin
            btn_sync   <= {btn_sync[0], ext_btn_signal};
            btn_sync_d <= btn_sync[1];

            if (trigger_fire) begin
                trigger_out_active <= 1'b1;
                trig_hold_cnt      <= TRIG_HOLD_CYCLES - 1;
            end else if (trigger_out_active) begin
                if (trig_hold_cnt == 0) begin
                    trigger_out_active <= 1'b0;
                end else begin
                    trig_hold_cnt <= trig_hold_cnt - 1'b1;
                end
            end
        end
    end

    assign triggerOut1 = trigger_out_active;
    assign triggerOut2 = trigger_out_active;
    assign triggerOut3 = trigger_out_active;
    assign triggerOut4 = trigger_out_active;
    assign triggerOut5 = trigger_out_active;

    // The Pulser Ring Counter
    timePulse #(
        .NUM_CHANNELS(10)
    ) pulser (
        .clk_var      (clk_var_20mhz),
        .n_rst        (n_rst_var),
        .trigger_sync (trigger_fire),
        .pulse        (output_pulse)             
    );

    // LED Status Logic
    always_comb begin
        led4_r = 1'b0;
        led4_g = 1'b0;
        led4_b = 1'b0;

        if (!drp_is_ready || !locked) begin
            led4_r = 1'b1; 
        end else if (drp_saddr > BASE_STATE) begin
            led4_g = 1'b1; 
        end else if (drp_saddr < BASE_STATE) begin
            led4_b = 1'b1; 
        end else begin
            led4_r = 1'b1; led4_g = 1'b1; led4_b = 1'b1;
        end
    end

endmodule