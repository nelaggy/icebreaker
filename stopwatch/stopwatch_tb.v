`default_nettype none
`timescale 1ns / 1ps

module stopwatch_tb;
	reg CLK = 0;
	reg BTN_N = 1, BTN1 = 0, BTN2 = 0, BTN3 = 0;
	wire LED1, LED2, LED3, LED4, LED5;
	wire P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10;

	always #41.667 CLK = ~CLK;   // 12 MHz

	top dut (
		.CLK(CLK), .BTN_N(BTN_N), .BTN1(BTN1), .BTN2(BTN2), .BTN3(BTN3),
		.LED1(LED1), .LED2(LED2), .LED3(LED3), .LED4(LED4), .LED5(LED5),
		.P1A1(P1A1), .P1A2(P1A2), .P1A3(P1A3), .P1A4(P1A4),
		.P1A7(P1A7), .P1A8(P1A8), .P1A9(P1A9), .P1A10(P1A10)
	);

	// 1,200,000 clocks = one BCD tick (100 ms at 12 MHz)
	task wait_ticks(input integer n);
		integer i;
		for (i = 0; i < n * 1_200_001; i = i + 1) @(posedge CLK);
	endtask

	// Pulse a button for 4 clocks (BTN_N is active-low).
	task reset; begin BTN_N=0; repeat(4) @(posedge CLK); BTN_N=1; @(posedge CLK); end endtask
	task start; begin BTN3 =1; repeat(4) @(posedge CLK); BTN3 =0; @(posedge CLK); end endtask
	task stop;  begin BTN1 =1; repeat(4) @(posedge CLK); BTN1 =0; @(posedge CLK); end endtask
	task lap;   begin BTN2 =1; repeat(4) @(posedge CLK); BTN2 =0; @(posedge CLK); end endtask

	// Pass/fail check
	integer errors = 0;
	task check(input [255:0] name, input [31:0] got, input [31:0] exp);
		begin
			if (got === exp) $display("  PASS  %0s: %0d", name, got);
			else begin $display("  FAIL  %0s: got %0d, expected %0d", name, got, exp);
				errors = errors + 1; end
		end
	endtask

	reg [7:0] snapshot;

	initial begin
		$dumpfile("stopwatch_tb.vcd");
		$dumpvars(0, stopwatch_tb);

		repeat (5) @(posedge CLK);

		reset;                                   // RESET
		check("after reset: display", dut.display_value, 0);
		check("after reset: running", dut.running,       0);

		start; wait_ticks(3);                     // START, count 3 ticks
		check("after 3 ticks: display", dut.display_value, 3);
		check("after start:   running", dut.running,       1);

		lap;                                    // LAP
		check("lap_value",   dut.lap_value,   3);
		check("lap_timeout", dut.lap_timeout, 20);

		wait_ticks(2);
		stop;                                    // STOP
		wait_ticks(1);
		check("after stop: display", dut.display_value, 5);
		check("after stop: running", dut.running,       0);

		snapshot = dut.display_value;
		wait_ticks(2);
		check("counter frozen", dut.display_value, snapshot);

		reset;                                   // RESET again
		check("after reset: display", dut.display_value, 0);

		$display(errors ? "\n%0d FAILURES" : "\nALL TESTS PASSED", errors);
		$finish;
	end
endmodule
