`timescale 1ps/1ps

module mmcme2_drp #(
    parameter REGISTER_LOCKED       = "Reg",
    parameter USE_REG_LOCKED        = "No",
    
    // Hardcoded VCO to 1000 MHz (100 MHz in * 10 / 1)
    parameter S1_CLKFBOUT_MULT      = 10,
    parameter S1_CLKFBOUT_PHASE     = 0,
    parameter S1_CLKFBOUT_FRAC      = 0,
    parameter S1_CLKFBOUT_FRAC_EN   = 0,
    parameter S1_BANDWIDTH          = "LOW",
    parameter S1_DIVCLK_DIVIDE      = 1,

    // Base properties for remaining channels (Kept constant across all states)
    parameter S1_CLKOUT0_FRAC_EN    = 1,
    parameter S1_CLKOUT1_DIVIDE     = 2,
    parameter S1_CLKOUT1_PHASE      = 0,
    parameter S1_CLKOUT1_DUTY       = 50000,
    parameter S1_CLKOUT2_DIVIDE     = 3,
    parameter S1_CLKOUT2_PHASE      = 0,
    parameter S1_CLKOUT2_DUTY       = 50000,
    parameter S1_CLKOUT3_DIVIDE     = 4,
    parameter S1_CLKOUT3_PHASE      = 0,
    parameter S1_CLKOUT3_DUTY       = 50000,
    parameter S1_CLKOUT4_DIVIDE     = 5,
    parameter S1_CLKOUT4_PHASE      = 0,
    parameter S1_CLKOUT4_DUTY       = 50000,
    parameter S1_CLKOUT5_DIVIDE     = 5,
    parameter S1_CLKOUT5_PHASE      = 0,
    parameter S1_CLKOUT5_DUTY       = 50000,
    parameter S1_CLKOUT6_DIVIDE     = 5,
    parameter S1_CLKOUT6_PHASE      = -90,
    parameter S1_CLKOUT6_DUTY       = 50000
) (
    input      [4:0]  SADDR, // 5-bit address for 21 states
    input             SEN,
    input             SCLK,
    input             RST,
    output reg        SRDY,
    
    input      [15:0] DO,
    input             DRDY,
    input             LOCK_REG_CLK_IN,
    input             LOCKED_IN,
    output reg        DWE,
    output reg        DEN,
    output reg [6:0]  DADDR,
    output reg [15:0] DI,
    output            DCLK,
    output reg        RST_MMCM,
    output            LOCKED_OUT
);

    wire IntLocked;
    wire IntRstMmcm;
    localparam TCQ = 100;

    (* rom_style = "distributed" *)
    reg [38:0]  rom [511:0]; // Expanded ROM
    reg [8:0]   rom_addr;    // Expanded Address
    reg [38:0]  rom_do;
    reg         next_srdy;
    reg [8:0]   next_rom_addr; // Expanded Address
    reg [6:0]   next_daddr;
    reg         next_dwe;
    reg         next_den;
    reg         next_rst_mmcm;
    reg [15:0]  next_di;
    
    generate
        if (REGISTER_LOCKED == "NoReg" && USE_REG_LOCKED == "No") begin
            assign LOCKED_OUT = LOCKED_IN;
            assign IntLocked = LOCKED_IN;
        end else if (REGISTER_LOCKED == "Reg" && USE_REG_LOCKED == "No") begin
            FDRE #(
                .INIT(0), .IS_C_INVERTED(0), .IS_D_INVERTED(0), .IS_R_INVERTED(0)
            ) mmcme3_drp_I_Fdrp (
                .D(LOCKED_IN), .CE(1'b1), .R(IntRstMmcm), .C(LOCK_REG_CLK_IN), .Q(LOCKED_OUT)
            );
            assign IntLocked = LOCKED_IN;
        end else if (REGISTER_LOCKED == "Reg" && USE_REG_LOCKED == "Yes") begin
            FDRE #(
                .INIT(0), .IS_C_INVERTED(0), .IS_D_INVERTED(0), .IS_R_INVERTED(0)
            ) mmcme3_drp_I_Fdrp (
                .D(LOCKED_IN), .CE(1'b1), .R(IntRstMmcm), .C(LOCK_REG_CLK_IN), .Q(LOCKED_OUT)
            );
            assign IntLocked = LOCKED_OUT;
        end
    endgenerate

    assign DCLK = SCLK;
    assign IntRstMmcm = RST_MMCM;

    `include "mmcme2_drp_func.h"

    // Base constant calculations for unchanged channels
    localparam [37:0] S1_CLKFBOUT = mmcm_count_calc(S1_CLKFBOUT_MULT, S1_CLKFBOUT_PHASE, 50000);
    localparam [37:0] S1_CLKFBOUT_FRAC_CALC = mmcm_frac_count_calc(S1_CLKFBOUT_MULT, S1_CLKFBOUT_PHASE, 50000, S1_CLKFBOUT_FRAC);
    localparam [9:0]  S1_DIGITAL_FILT = mmcm_filter_lookup(S1_CLKFBOUT_MULT, S1_BANDWIDTH);
    localparam [39:0] S1_LOCK = mmcm_lock_lookup(S1_CLKFBOUT_MULT);
    localparam [37:0] S1_DIVCLK = mmcm_count_calc(S1_DIVCLK_DIVIDE, 0, 50000);
    localparam [37:0] S1_CLKOUT1 = mmcm_count_calc(S1_CLKOUT1_DIVIDE, S1_CLKOUT1_PHASE, S1_CLKOUT1_DUTY);
    localparam [37:0] S1_CLKOUT2 = mmcm_count_calc(S1_CLKOUT2_DIVIDE, S1_CLKOUT2_PHASE, S1_CLKOUT2_DUTY);
    localparam [37:0] S1_CLKOUT3 = mmcm_count_calc(S1_CLKOUT3_DIVIDE, S1_CLKOUT3_PHASE, S1_CLKOUT3_DUTY);
    localparam [37:0] S1_CLKOUT4 = mmcm_count_calc(S1_CLKOUT4_DIVIDE, S1_CLKOUT4_PHASE, S1_CLKOUT4_DUTY);
    localparam [37:0] S1_CLKOUT5 = mmcm_count_calc(S1_CLKOUT5_DIVIDE, S1_CLKOUT5_PHASE, S1_CLKOUT5_DUTY);
    localparam [37:0] S1_CLKOUT6 = mmcm_count_calc(S1_CLKOUT6_DIVIDE, S1_CLKOUT6_PHASE, S1_CLKOUT6_DUTY);

    integer ii, state_idx, div_val, frac_val;
    reg [37:0] clkout0_calc;

    initial begin
        // Zero initialize entire ROM
        for(ii = 0; ii < 512; ii = ii + 1) begin
            rom[ii] = 39'b0;
        end

        // Dynamically calculate and pack all 21 states (45.0 ns to 55.0 ns)
        for(state_idx = 0; state_idx <= 20; state_idx = state_idx + 1) begin
            div_val  = 45 + (state_idx / 2);
            frac_val = (state_idx % 2) ? 500 : 0;
            
            if (S1_CLKOUT0_FRAC_EN == 0) begin
               clkout0_calc = mmcm_count_calc(div_val, 0, 50000);
            end else begin
               clkout0_calc = mmcm_frac_count_calc(div_val, 0, 50000, frac_val);
            end

            rom[state_idx*23 + 0]  = {7'h28, 16'h0000, 16'hFFFF}; // Power
            rom[state_idx*23 + 1]  = {7'h09, 16'h8000, clkout0_calc[31:16]}; 
            rom[state_idx*23 + 2]  = {7'h08, 16'h1000, clkout0_calc[15:0]};  
            
            rom[state_idx*23 + 3]  = {7'h0A, 16'h1000, S1_CLKOUT1[15:0]};
            rom[state_idx*23 + 4]  = {7'h0B, 16'hFC00, S1_CLKOUT1[31:16]};
            rom[state_idx*23 + 5]  = {7'h0C, 16'h1000, S1_CLKOUT2[15:0]};
            rom[state_idx*23 + 6]  = {7'h0D, 16'hFC00, S1_CLKOUT2[31:16]};
            rom[state_idx*23 + 7]  = {7'h0E, 16'h1000, S1_CLKOUT3[15:0]};
            rom[state_idx*23 + 8]  = {7'h0F, 16'hFC00, S1_CLKOUT3[31:16]};
            rom[state_idx*23 + 9]  = {7'h10, 16'h1000, S1_CLKOUT4[15:0]};
            rom[state_idx*23 + 10] = {7'h11, 16'hFC00, S1_CLKOUT4[31:16]};
            rom[state_idx*23 + 11] = {7'h06, 16'h1000, S1_CLKOUT5[15:0]};
            
            // Xilinx Quirk: CLKOUT0 frac bits [35:32] are shared in CLKOUT5 register 0x07
            rom[state_idx*23 + 12] = (S1_CLKOUT0_FRAC_EN == 0) ?
                                     {7'h07, 16'hC000, S1_CLKOUT5[31:16]}:
                                     {7'h07, 16'hC000, S1_CLKOUT5[31:30], clkout0_calc[35:32], S1_CLKOUT5[25:16]};
            
            rom[state_idx*23 + 13] = {7'h12, 16'h1000, S1_CLKOUT6[15:0]};
            rom[state_idx*23 + 14] = (S1_CLKFBOUT_FRAC_EN == 0) ?
                                     {7'h13, 16'hC000, S1_CLKOUT6[31:16]}:
                                     {7'h13, 16'hC000, S1_CLKOUT6[31:30], S1_CLKFBOUT_FRAC_CALC[35:32], S1_CLKOUT6[25:16]};

            rom[state_idx*23 + 15] = {7'h16, 16'hC000, {2'h0, S1_DIVCLK[23:22], S1_DIVCLK[11:0]} };

            rom[state_idx*23 + 16] = (S1_CLKFBOUT_FRAC_EN == 0) ?
                                     {7'h14, 16'h1000, S1_CLKFBOUT[15:0]}:
                                     {7'h14, 16'h1000, S1_CLKFBOUT_FRAC_CALC[15:0]};

            rom[state_idx*23 + 17] = (S1_CLKFBOUT_FRAC_EN == 0) ?
                                     {7'h15, 16'h8000, S1_CLKFBOUT[31:16]}:
                                     {7'h15, 16'h8000, S1_CLKFBOUT_FRAC_CALC[31:16]};

            rom[state_idx*23 + 18] = {7'h18, 16'hFC00, {6'h00, S1_LOCK[29:20]} };
            rom[state_idx*23 + 19] = {7'h19, 16'h8000, {1'b0 , S1_LOCK[34:30], S1_LOCK[9:0]} };
            rom[state_idx*23 + 20] = {7'h1A, 16'h8000, {1'b0 , S1_LOCK[39:35], S1_LOCK[19:10]} };
            rom[state_idx*23 + 21] = {7'h4E, 16'h66FF, S1_DIGITAL_FILT[9], 2'h0, S1_DIGITAL_FILT[8:7], 2'h0, S1_DIGITAL_FILT[6], 8'h00 };
            rom[state_idx*23 + 22] = {7'h4F, 16'h666F, S1_DIGITAL_FILT[5], 2'h0, S1_DIGITAL_FILT[4:3], 2'h0, S1_DIGITAL_FILT[2:1], 2'h0, S1_DIGITAL_FILT[0], 4'h0 };
        end
    end

    always @(posedge SCLK) begin
       rom_do <= #TCQ rom[rom_addr];
    end

    localparam RESTART     = 4'h1;
    localparam WAIT_LOCK   = 4'h2;
    localparam WAIT_SEN    = 4'h3;
    localparam ADDRESS     = 4'h4;
    localparam WAIT_A_DRDY = 4'h5;
    localparam BITMASK     = 4'h6;
    localparam BITSET      = 4'h7;
    localparam WRITE       = 4'h8;
    localparam WAIT_DRDY   = 4'h9;

    reg [3:0]  current_state = RESTART;
    reg [3:0]  next_state    = RESTART;

    localparam STATE_COUNT_CONST  = 23;
    reg [4:0] state_count      = STATE_COUNT_CONST;
    reg [4:0] next_state_count = STATE_COUNT_CONST;

    always @(posedge SCLK) begin
       DADDR       <= #TCQ next_daddr;
       DWE         <= #TCQ next_dwe;
       DEN         <= #TCQ next_den;
       RST_MMCM    <= #TCQ next_rst_mmcm;
       DI          <= #TCQ next_di;
       SRDY        <= #TCQ next_srdy;
       rom_addr    <= #TCQ next_rom_addr;
       state_count <= #TCQ next_state_count;
    end

    always @(posedge SCLK) begin
       if(RST) current_state <= #TCQ RESTART;
       else    current_state <= #TCQ next_state;
    end

    always @* begin
       next_srdy         = 1'b0;
       next_daddr        = DADDR;
       next_dwe          = 1'b0;
       next_den          = 1'b0;
       next_rst_mmcm     = RST_MMCM;
       next_di           = DI;
       next_rom_addr     = rom_addr;
       next_state_count  = state_count;

       case (current_state)
          RESTART: begin
             next_daddr     = 7'h00;
             next_di        = 16'h0000;
             next_rom_addr  = 9'h000;
             next_rst_mmcm  = 1'b1;
             next_state     = WAIT_LOCK;
          end

          WAIT_LOCK: begin
             next_rst_mmcm    = 1'b0;
             next_state_count = STATE_COUNT_CONST ;
             next_rom_addr    = SADDR * STATE_COUNT_CONST;
             if(IntLocked) begin
                next_state = WAIT_SEN;
                next_srdy  = 1'b1;
             end else begin
                next_state = WAIT_LOCK;
             end
          end

          WAIT_SEN: begin
             next_rom_addr = SADDR * STATE_COUNT_CONST;
             if (SEN) begin
                next_rom_addr = SADDR * STATE_COUNT_CONST;
                next_state    = ADDRESS;
             end else begin
                next_state    = WAIT_SEN;
             end
          end

          ADDRESS: begin
             next_rst_mmcm = 1'b1;
             next_den      = 1'b1;
             next_daddr    = rom_do[38:32];
             next_state    = WAIT_A_DRDY;
          end

          WAIT_A_DRDY: begin
             if (DRDY) next_state = BITMASK;
             else      next_state = WAIT_A_DRDY;
          end

          BITMASK: begin
             next_di    = rom_do[31:16] & DO;
             next_state = BITSET;
          end

          BITSET: begin
             next_di       = rom_do[15:0] | DI;
             next_rom_addr = rom_addr + 1'b1;
             next_state    = WRITE;
          end

          WRITE: begin
             next_dwe         = 1'b1;
             next_den         = 1'b1;
             next_state_count = state_count - 1'b1;
             next_state       = WAIT_DRDY;
          end

          WAIT_DRDY: begin
             if(DRDY) begin
                if(state_count > 0) next_state = ADDRESS;
                else                next_state = WAIT_LOCK;
             end else begin
                next_state = WAIT_DRDY;
             end
          end

          default: next_state = RESTART;
       endcase
    end
endmodule