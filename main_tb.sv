`timescale 1ns/1ps

module main_tb;
	logic clk_100mhz;
	logic n_rst;
	logic trigger;
	logic add5ns;
	logic sub5ns;
	logic [9:0] output_pulse;
    logic locked;

	top dut (
		.clk_100mhz(clk_100mhz),
		.n_rst(n_rst),
		.trigger(trigger),
		.add5ns(add5ns),
		.sub5ns(sub5ns),
		.output_pulse(output_pulse),
        .locked(locked)
	);

	// 100 MHz clock (10 ns period)
	initial clk_100mhz = 1'b0;
	always #5 clk_100mhz = ~clk_100mhz;

	initial begin
		n_rst = 1'b0;
		trigger = 1'b0;
		add5ns = 1'b0;
		sub5ns = 1'b0;

		#50;
		n_rst = 1'b1;

        @(posedge locked);
		#100;

		trigger = 1'b1;
		#10;
		trigger = 1'b0;

		#1000;

		// Second run: add 5 ns
		add5ns = 1'b1;
		trigger = 1'b1;
		#20;
		trigger = 1'b0;
		add5ns = 1'b0;

		#1200;

		// Third run: sub 5 ns
		sub5ns = 1'b1;
		trigger = 1'b1;
		#20;
		trigger = 1'b0;
		sub5ns = 1'b0;

		#1200;

		$finish;
	end

	// Basic pulse activity log
	always @(output_pulse) begin
		if (output_pulse != 10'b0) begin
			$display("%0t ns : output_pulse = %b", $time, output_pulse);
		end
	end

endmodule
