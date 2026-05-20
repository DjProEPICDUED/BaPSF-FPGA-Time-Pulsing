`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Simple behavioral model for the MMCM used by top
// -----------------------------------------------------------------------------
module clk_wiz_0 (
	input  logic clk_in1,
	output logic clk_out1,
	output logic clk_out2,
	input  logic psclk,
	input  logic psen,
	input  logic psincdec,
	output logic psdone,
	input  logic reset,
	output logic locked
);
	timeunit 1ns;
	timeprecision 1ps;

	localparam time HALF_200MHZ = 2.5ns;
	localparam time SHIFT_STEP  = 18ps;   // ~17.85ps per MMCM step
	localparam time MAX_SHIFT   = 900ps;  // clamp to a safe range

	time shift_delay;
	int  lock_count;

	initial begin
		clk_out1 = 1'b0;
		clk_out2 = 1'b0;
	end

	// Base 200MHz clock
	always #HALF_200MHZ clk_out1 = ~clk_out1;

	// Shifted 200MHz clock driven by a variable delay
	always @(clk_out1) clk_out2 <= #(shift_delay) clk_out1;

	// Simple lock model
	always_ff @(posedge clk_in1 or posedge reset) begin
		if (reset) begin
			lock_count <= 0;
			locked <= 1'b0;
		end else if (!locked) begin
			if (lock_count >= 20) begin
				locked <= 1'b1;
			end else begin
				lock_count <= lock_count + 1;
			end
		end
	end

	// Phase shift handshake and delay update
	always_ff @(posedge psclk or posedge reset) begin
		if (reset) begin
			psdone <= 1'b0;
			shift_delay <= 0;
		end else begin
			psdone <= psen; // one-cycle ack after PSEN
			if (psdone) begin
				if (psincdec) begin
					if (shift_delay + SHIFT_STEP <= MAX_SHIFT)
						shift_delay <= shift_delay + SHIFT_STEP;
					else
						shift_delay <= MAX_SHIFT;
				end else begin
					if (shift_delay >= SHIFT_STEP)
						shift_delay <= shift_delay - SHIFT_STEP;
					else
						shift_delay <= 0;
				end
			end
		end
	end
endmodule

// -----------------------------------------------------------------------------
// Main testbench
// -----------------------------------------------------------------------------
module main_tb;
	timeunit 1ns;
	timeprecision 1ps;

	localparam int  NUM_CH        = 4;
	localparam int  DELAY_CYCLES  = 4;
	localparam time BASE_HALF     = 2.5ns;
	localparam time BASE_PERIOD   = 5ns;
	localparam time SHIFT_DELAY   = 1ns;
	localparam time EXPECTED_GAP  = ((DELAY_CYCLES + 1) * BASE_PERIOD) - SHIFT_DELAY;
	localparam time EXPECTED_WIDTH = (DELAY_CYCLES * BASE_PERIOD) - SHIFT_DELAY;
	localparam time GAP_TOLERANCE = 1ns;
	localparam time WIDTH_TOLERANCE = 2ns;
	localparam time MMCM_SHIFT_TIMEOUT = 2000ns;

	// ------------------------------------------------------------------
	// Clocks
	// ------------------------------------------------------------------
	logic clk_base;
	logic clk_shifted;
	logic clk_100;

	initial begin
		clk_base = 1'b0;
		clk_shifted = 1'b0;
		clk_100 = 1'b0;
	end

	always #BASE_HALF clk_base = ~clk_base;     // 200MHz
	always @(clk_base) clk_shifted <= #(SHIFT_DELAY) clk_base;

	always #5ns clk_100 = ~clk_100;             // 100MHz

	// ------------------------------------------------------------------
	// dual_timePulser unit under test
	// ------------------------------------------------------------------
	logic n_rst_dual;
	logic trigger_dual;
	logic [NUM_CH-1:0] pulse_dual;

	dual_timePulser #(
		.NUM_CHANNELS(NUM_CH),
		.DELAY_CYCLES(DELAY_CYCLES)
	) dut_dual (
		.clk_base(clk_base),
		.clk_shifted(clk_shifted),
		.n_rst(n_rst_dual),
		.trigger(trigger_dual),
		.pulse(pulse_dual)
	);

	// Edge capture for pulse timing checks
	time rise_time[NUM_CH];
	time fall_time[NUM_CH];
	int  rise_count[NUM_CH];
	int  fall_count[NUM_CH];

	genvar gi;
	generate
		for (gi = 0; gi < NUM_CH; gi++) begin : gen_pulse_edges
			always @(posedge pulse_dual[gi]) begin
				rise_time[gi] = $time;
				rise_count[gi]++;
			end
			always @(negedge pulse_dual[gi]) begin
				fall_time[gi] = $time;
				fall_count[gi]++;
			end
		end
	endgenerate

	function automatic bit all_falls_done;
		for (int i = 0; i < NUM_CH; i++) begin
			if (fall_count[i] < 1)
				return 1'b0;
		end
		return 1'b1;
	endfunction

	// ------------------------------------------------------------------
	// mmcm_shifter unit under test
	// ------------------------------------------------------------------
	logic n_rst_mmcm;
	logic btn_add_mmcm;
	logic btn_sub_mmcm;
	logic psen_mmcm;
	logic psincdec_mmcm;
	logic psdone_mmcm;

	int  psen_count_mmcm;
	logic psincdec_first_mmcm;

	mmcm_shifter dut_mmcm (
		.clk_100mhz(clk_100),
		.n_rst(n_rst_mmcm),
		.btn_add_half_ns(btn_add_mmcm),
		.btn_sub_half_ns(btn_sub_mmcm),

		.psen(psen_mmcm),
		.psincdec(psincdec_mmcm),
		.psdone(psdone_mmcm)
	);

	// Generate a simple psdone response (one cycle after psen)
	always_ff @(posedge clk_100 or negedge n_rst_mmcm) begin
		if (!n_rst_mmcm)
			psdone_mmcm <= 1'b0;
		else
			psdone_mmcm <= psen_mmcm;
	end

	always_ff @(posedge clk_100 or negedge n_rst_mmcm) begin
		if (!n_rst_mmcm) begin
			psen_count_mmcm <= 0;
			psincdec_first_mmcm <= 1'b0;
		end else begin
			if (psen_mmcm) begin
				if (psen_count_mmcm == 0)
					psincdec_first_mmcm <= psincdec_mmcm;
				psen_count_mmcm <= psen_count_mmcm + 1;
			end
		end
	end

	// ------------------------------------------------------------------
	// top-level integration under test
	// ------------------------------------------------------------------
	logic rst_top;
	logic trigger_top;
	logic ext_btn_top;
	logic btn_add_top;
	logic btn_sub_top;
	logic [9:0] output_pulse_top;
	logic locked_top;
	logic led4_r_top;
	logic led4_g_top;
	logic led4_b_top;

	int  psen_count_top;
	logic psincdec_first_top;

	top dut_top (
		.clk_100mhz(clk_100),
		.rst(rst_top),
		.trigger(trigger_top),
		.ext_btn_signal(ext_btn_top),
		.btn_add_half_ns(btn_add_top),
		.btn_sub_half_ns(btn_sub_top),

		.output_pulse(output_pulse_top),
		.locked(locked_top),

		.led4_r(led4_r_top),
		.led4_g(led4_g_top),
		.led4_b(led4_b_top)
	);

	always_ff @(posedge clk_100) begin
		if (rst_top) begin
			psen_count_top <= 0;
			psincdec_first_top <= 1'b0;
		end else if (dut_top.psen) begin
			if (psen_count_top == 0)
				psincdec_first_top <= dut_top.psincdec;
			psen_count_top <= psen_count_top + 1;
		end
	end

	// ------------------------------------------------------------------
	// Test sequences
	// ------------------------------------------------------------------
	task automatic run_dual_timePulser_test;
		time wait_start;
		time gap;
		time width;
		begin
			n_rst_dual = 1'b0;
			trigger_dual = 1'b0;

			for (int i = 0; i < NUM_CH; i++) begin
				rise_count[i] = 0;
				fall_count[i] = 0;
				rise_time[i] = 0;
				fall_time[i] = 0;
			end

			repeat (4) @(posedge clk_base);
			n_rst_dual = 1'b1;

			// Drive a clean trigger pulse
			@(posedge clk_base);
			trigger_dual = 1'b1;
			repeat (2) @(posedge clk_base);
			trigger_dual = 1'b0;

			// Wait for all channels to complete
			wait_start = $time;
			while (!all_falls_done()) begin
				#1ns;
				if ($time - wait_start > 400ns) begin
					$fatal(1, "dual_timePulser: timeout waiting for pulses to finish");
				end
			end

			for (int i = 0; i < NUM_CH; i++) begin
				if (rise_count[i] != 1)
					$fatal(1, "dual_timePulser: channel %0d rise_count=%0d", i, rise_count[i]);
				if (fall_count[i] != 1)
					$fatal(1, "dual_timePulser: channel %0d fall_count=%0d", i, fall_count[i]);
				if (fall_time[i] <= rise_time[i])
					$fatal(1, "dual_timePulser: channel %0d width invalid", i);

				width = fall_time[i] - rise_time[i];
				if (width < EXPECTED_WIDTH || width > EXPECTED_WIDTH + WIDTH_TOLERANCE)
					$fatal(1, "dual_timePulser: channel %0d width=%0t", i, width);
			end

			for (int i = 1; i < NUM_CH; i++) begin
				gap = rise_time[i] - rise_time[i-1];
				if (gap < EXPECTED_GAP - GAP_TOLERANCE || gap > EXPECTED_GAP + GAP_TOLERANCE)
					$fatal(1, "dual_timePulser: channel gap %0d->%0d = %0t", i-1, i, gap);
			end

			$display("dual_timePulser test passed");
		end
	endtask

	task automatic run_mmcm_shifter_test;
		time wait_start;
		int snapshot;
		begin
			n_rst_mmcm = 1'b0;
			btn_add_mmcm = 1'b0;
			btn_sub_mmcm = 1'b0;
			repeat (3) @(posedge clk_100);
			n_rst_mmcm = 1'b1;

			// Add half-ns test
			@(posedge clk_100);
			btn_add_mmcm = 1'b1;
			@(posedge clk_100);
			btn_add_mmcm = 1'b0;

			wait_start = $time;
			while (psen_count_mmcm < 28) begin
				@(posedge clk_100);
				if ($time - wait_start > MMCM_SHIFT_TIMEOUT)
					$fatal(1, "mmcm_shifter: add sequence timeout");
			end

			if (psincdec_first_mmcm != 1'b1)
				$fatal(1, "mmcm_shifter: add sequence psincdec not set");

			// Verify it stops after 28 shifts
			snapshot = psen_count_mmcm;
			repeat (5) @(posedge clk_100);
			if (psen_count_mmcm != snapshot)
				$fatal(1, "mmcm_shifter: extra shifts after add");

			// Subtract half-ns test
			n_rst_mmcm = 1'b0;
			repeat (2) @(posedge clk_100);
			n_rst_mmcm = 1'b1;

			@(posedge clk_100);
			btn_sub_mmcm = 1'b1;
			@(posedge clk_100);
			btn_sub_mmcm = 1'b0;

			wait_start = $time;
			while (psen_count_mmcm < 28) begin
				@(posedge clk_100);
				if ($time - wait_start > MMCM_SHIFT_TIMEOUT)
					$fatal(1, "mmcm_shifter: sub sequence timeout");
			end

			if (psincdec_first_mmcm != 1'b0)
				$fatal(1, "mmcm_shifter: sub sequence psincdec not cleared");

			$display("mmcm_shifter test passed");
		end
	endtask

	task automatic run_top_test;
		time wait_start;
		begin
			rst_top = 1'b1;
			trigger_top = 1'b0;
			ext_btn_top = 1'b0;
			btn_add_top = 1'b0;
			btn_sub_top = 1'b0;
			psen_count_top = 0;
			psincdec_first_top = 1'b0;

			repeat (4) @(posedge clk_100);
			rst_top = 1'b0;

			// Wait for lock
			wait_start = $time;
			while (locked_top !== 1'b1) begin
				@(posedge clk_100);
				if ($time - wait_start > 2000ns)
					$fatal(1, "top: lock timeout");
			end

			if (led4_b_top !== 1'b1)
				$fatal(1, "top: led4_b should track locked");

			// Trigger sequence
			@(posedge clk_100);
			trigger_top = 1'b1;
			repeat (2) @(posedge clk_100);
			trigger_top = 1'b0;

			wait_start = $time;
			while ($isunknown(output_pulse_top) || (output_pulse_top === 10'b0)) begin
				@(posedge clk_100);
				if ($time - wait_start > 2000ns)
					$fatal(1, "top: no pulses observed after trigger");
			end

			// Allow all pulses to finish
			#800ns;
			if (output_pulse_top !== 10'b0)
				$fatal(1, "top: pulses did not return to zero");

			// Button LED checks
			btn_add_top = 1'b1;
			#1ns;
			if (led4_g_top !== 1'b1)
				$fatal(1, "top: led4_g should track btn_add_half_ns");
			btn_add_top = 1'b0;

			btn_sub_top = 1'b1;
			#1ns;
			if (led4_r_top !== 1'b1)
				$fatal(1, "top: led4_r should track btn_sub_half_ns");
			btn_sub_top = 1'b0;

			// MMCM shift control via top
			@(posedge clk_100);
			btn_add_top = 1'b1;
			@(posedge clk_100);
			btn_add_top = 1'b0;

			wait_start = $time;
			while (psen_count_top < 28) begin
				@(posedge clk_100);
				if ($time - wait_start > 3000ns)
					$fatal(1, "top: psen sequence timeout");
			end

			if (psincdec_first_top != 1'b1)
				$fatal(1, "top: psincdec should be set during add");

			$display("top test passed");
		end
	endtask

	// ------------------------------------------------------------------
	// Run all tests
	// ------------------------------------------------------------------
	initial begin
		run_dual_timePulser_test();
		run_mmcm_shifter_test();
		run_top_test();
		$display("All tests passed");
		$finish;
	end

endmodule
