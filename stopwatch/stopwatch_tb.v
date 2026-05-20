`include "stopwatch/stopwatch.v"
`default_nettype none
`timescale 1ns/1ns

module stopwatch_tb;
	reg CLK;
	reg BTN_N, BTN1, BTN2, BTN3;
	wire LED1, LED2, LED3, LED4, LED5;
	wire P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10;

	always #41.667 CLK = ~CLK;   // 12 MHz

	top dut (
		.CLK(CLK), .BTN_N(BTN_N), .BTN1(BTN1), .BTN2(BTN2), .BTN3(BTN3),
		.LED1(LED1), .LED2(LED2), .LED3(LED3), .LED4(LED4), .LED5(LED5),
		.P1A1(P1A1), .P1A2(P1A2), .P1A3(P1A3), .P1A4(P1A4),
		.P1A7(P1A7), .P1A8(P1A8), .P1A9(P1A9), .P1A10(P1A10)
	);
	localparam CLK_PER_TICK = 120;   // derived: period = CLKDIV_MAX+1 = 120
	defparam dut.CLKDIV_MAX = CLK_PER_TICK - 1;   // 119, so counter wraps at 119

	// clocks per BCD tick: mirrors 1_200_000 for 1_200_001-period original
	task wait_ticks(input integer n);
		integer i;
		for (i = 0; i < n * CLK_PER_TICK; i = i + 1) @(posedge CLK);
	endtask

	task sync; @(negedge CLK); endtask

	task reset();
		begin
			BTN_N = 0; BTN1 = 0; BTN2 = 0; BTN3 = 0;
			@(posedge CLK);
			@(negedge CLK);
			BTN_N = 1;
		end
	endtask

	task start(); begin BTN3 = 1; @(posedge CLK); @(negedge CLK); BTN3 = 0; end endtask
	task stop();  begin BTN1 = 1; @(posedge CLK); @(negedge CLK); BTN1 = 0; end endtask
	task lap();   begin BTN2 = 1; @(posedge CLK); @(negedge CLK); BTN2 = 0; end endtask
	
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

	// ============================================
	// Verification Plan Summary
	//
	// T1  Reset Init          : display=0, running=0, no counting idle
	// T2  LED Comb Logic      : LED1=BTN1&BTN2, LED2=BTN1&BTN3, LED3=BTN2&BTN3,
	//                           LED4=!BTN_N, LED5=BTN1|BTN2|BTN3|!BTN_N
	// T3  Start Counting      : BTN3 starts, counter advances 0->5
	// T4  Stop Counting       : BTN1 stops, counter holds
	// T5  Resume After Stop   : counting continues from stopped value
	// T6  BCD Rollover 9->10  : low nibble wraps 9->10 (BCD 8'h10 = decimal 16)
	// T7  BCD Rollover 99->00 : full wrap 99->0 (BCD 8'h99 = decimal 153)
	// T8  Lap Capture         : BTN2 snapshots display_value, 20-tick timeout
	// T9  Lap While Stopped   : lap works when counter not running
	// T10 Lap Refresh         : BTN2 during active lap resets timeout, updates latch
	// T11 Reset While Running : BTN_N clears display/running/clkdiv
	// T12 Button Priority     : source-order: stop > start, reset display always
	// T13 Lap+Start Same Cyc  : simultaneous BTN2+BTN3, both effects apply
	// T14 Reset Unclear Lap   : BTN_N does NOT clear lap_timeout (counts down)
	//
	// BCD values in decimal: 0-9 single digit, 16=10, 153=99
	// Internal signals via hierarchical path: dut.display_value, etc.
	// ============================================
	initial begin
		$dumpfile("stopwatch_tb.vcd");
		$dumpvars(0, stopwatch_tb);
		CLK = 0; // start clock from known value
		reset(); #10;

		// ============================================
		$display("=== T1: Reset Initialization ===");
		// ============================================
		check("T1a: display after reset", dut.display_value, 0);
		check("T1b: running after reset", dut.running, 0);
		wait_ticks(2);
		sync;
		check("T1c: no counting when idle", dut.display_value, 0);
		BTN_N = 0;
		#0;
		check("T1d: LED4 active-low reset", LED4, 1);
		check("T1e: LED5 includes reset", LED5, 1);
		BTN_N = 1;

		// ============================================
		$display("=== T2: LED Combinational Logic ===");
		// ============================================
		reset(); #10;
		// all released (BTN_N=1)
		check("T2a: LED4 released", LED4, 0);
		check("T2b: LED5 released", LED5, 0);
		// BTN_N pressed
		BTN_N = 0;
		#0;
		check("T2c: LED4 active reset", LED4, 1);
		check("T2d: LED5 active reset", LED5, 1);
		BTN_N = 1;
		// single buttons
		BTN1 = 1;
		#0;
		check("T2e: LED1 BTN1 alone ", LED1, 0);
		check("T2f: LED5 BTN1 alone ", LED5, 1);
		BTN1 = 0;
		BTN2 = 1;
		#0;
		check("T2g: LED5 BTN2 alone ", LED5, 1);
		BTN2 = 0;
		BTN3 = 1;
		#0;
		check("T2h: LED5 BTN3 alone ", LED5, 1);
		BTN3 = 0;
		// pairs
		BTN1 = 1; BTN2 = 1;
		#0;
		check("T2i: LED1 BTN1+BTN2  ", LED1, 1);
		BTN1 = 0; BTN2 = 0;
		BTN1 = 1; BTN3 = 1;
		#0;
		check("T2j: LED2 BTN1+BTN3  ", LED2, 1);
		BTN1 = 0; BTN3 = 0;
		BTN2 = 1; BTN3 = 1;
		#0;
		check("T2k: LED3 BTN2+BTN3  ", LED3, 1);
		BTN2 = 0; BTN3 = 0;
		// triple
		BTN1 = 1; BTN2 = 1; BTN3 = 1;
		#0;
		check("T2l: LED1 triple     ", LED1, 1);
		check("T2m: LED2 triple     ", LED2, 1);
		check("T2n: LED3 triple     ", LED3, 1);
		check("T2o: LED5 triple     ", LED5, 1);
		BTN1 = 0; BTN2 = 0; BTN3 = 0;

		// ============================================
		$display("=== T3: Start Counting ===");
		// ============================================
		reset(); #10;
		start();
		check("T3a: running after start  ", dut.running, 1);
		wait_ticks(1);
		sync;
		check("T3b: display after 1 tick ", dut.display_value, 1);
		wait_ticks(4);
		sync;
		check("T3c: display after 5 ticks", dut.display_value, 5);

		// ============================================
		$display("=== T4: Stop Counting ===");
		// ============================================
		stop();
		check("T4a: running after stop", dut.running, 0);
		wait_ticks(5);
		sync;
		check("T4b: display frozen     ", dut.display_value, 5);

		// ============================================
		$display("=== T5: Resume After Stop ===");
		// ============================================
		start();
		check("T5a: running resumed", dut.running, 1);
		wait_ticks(2);
		sync;
		check("T5b: continued from 5", dut.display_value, 7);
		stop();

		// ============================================
		$display("=== T6: BCD Low-Nibble Rollover 9->10 ===");
		// ============================================
		reset(); #10;
		start();
		wait_ticks(9);
		sync;
		check("T6a: display at 9     ", dut.display_value, 9);
		wait_ticks(1);
		sync;
		check("T6b: BCD rollover 9->10", dut.display_value, 16);

		// ============================================
		$display("=== T7: BCD Full Rollover 99->00 ===");
		// ============================================
		wait_ticks(89);
		sync;
		check("T7a: display at 99      ", dut.display_value, 153);
		wait_ticks(1);
		sync;
		check("T7b: BCD rollover 99->00", dut.display_value, 0);
		stop();

		// ============================================
		$display("=== T8: Lap Capture ===");
		// ============================================
		reset(); #10;
		start();
		wait_ticks(5);
		sync;
		check("T8a: display at 5     ", dut.display_value, 5);
		lap();
		check("T8b: lap captured 5   ", dut.lap_value, 5);
		check("T8c: lap_timeout 20   ", dut.lap_timeout, 20);
		wait_ticks(20);
		sync;
		check("T8d: lap expired      ", dut.lap_timeout, 0);
		stop();

		// ============================================
		$display("=== T9: Lap While Stopped ===");
		// ============================================
		reset(); #10;
		start();
		wait_ticks(3);
		sync;
		stop();
		check("T9a: stopped at 3          ", dut.display_value, 3);
		lap();
		check("T9b: lap captured stopped 3", dut.lap_value, 3);
		check("T9c: lap_timeout 20        ", dut.lap_timeout, 20);
		wait_ticks(21);
		sync;
		check("T9d: lap expired           ", dut.lap_timeout, 0);

		// ============================================
		$display("=== T10: Lap Refresh During Active Lap ===");
		// ============================================
		reset(); #10;
		start();
		wait_ticks(3);
		sync;
		lap();
		check("T10a: first lap captures 3", dut.lap_value, 3);
		wait_ticks(5);
		sync;
		check("T10b: counting cont to 8  ", dut.display_value, 8);
		lap();
		check("T10c: lap refreshed to 8  ", dut.lap_value, 8);
		check("T10d: lap_timeout reset 20", dut.lap_timeout, 20);
		stop();

		// ============================================
		$display("=== T11: Reset While Running ===");
		// ============================================
		reset(); #10;
		start();
		wait_ticks(5);
		sync;
		check("T11a: display at 5        ", dut.display_value, 5);
		BTN_N = 0; @(posedge CLK); @(negedge CLK); BTN_N = 1;
		check("T11b: display reset to 0  ", dut.display_value, 0);
		check("T11c: running reset to 0  ", dut.running, 0);
		wait_ticks(3);
		sync;
		check("T11d: stays 0 after reset ", dut.display_value, 0);

		// ============================================
		$display("=== T12: Button Priority ===");
		// ============================================
		reset(); #10;
		// BTN_N + BTN3: BTN3 last assignment wins running
		BTN_N = 0; BTN3 = 1; @(posedge CLK); @(negedge CLK); BTN_N = 1; BTN3 = 0;
		check("T12a: BTN_N+BTN3 display 0", dut.display_value, 0);
		check("T12b: BTN_N+BTN3 running 1", dut.running, 1);

		reset(); #10;
		// BTN1 + BTN3: BTN1 (stop) last assignment overrides BTN3 (start)
		BTN1 = 1; BTN3 = 1; @(posedge CLK); @(negedge CLK); BTN1 = 0; BTN3 = 0;
		check("T12c: BTN1+BTN3 running 0", dut.running, 0);

		// BTN_N + BTN1 + BTN3: all three
		start(); wait_ticks(3);
		BTN_N = 0; BTN1 = 1; BTN3 = 1; @(posedge CLK); @(negedge CLK); BTN_N = 1; BTN1 = 0; BTN3 = 0;
		check("T12d: all btns display 0 ", dut.display_value, 0);
		check("T12e: all btns running 0 ", dut.running, 0);

		// ============================================
		$display("=== T13: Lap + Start Same Cycle ===");
		// ============================================
		reset(); #10;
		BTN2 = 1; BTN3 = 1; @(posedge CLK); @(negedge CLK); BTN2 = 0; BTN3 = 0;
		check("T13a: running set         ", dut.running, 1);
		check("T13b: lap captures 0      ", dut.lap_value, 0);
		check("T13c: lap_timeout 20      ", dut.lap_timeout, 20);
		stop();

		// ============================================
		$display("=== T14: Reset Does Not Clear lap_timeout ===");
		// ============================================
		reset(); #10;
		start();
		wait_ticks(5);
		sync;
		lap();
		wait_ticks(5);
		sync;
		snapshot = dut.lap_timeout;
		BTN_N = 0; @(posedge CLK); @(negedge CLK); BTN_N = 1;
		check("T14a: display reset to 0   ", dut.display_value, 0);
		check("T14b: lap_timeout NOT cleared", dut.lap_timeout == snapshot, 1);
		wait_ticks(1);
		sync;
		check("T14c: lap_timeout still runs ", dut.lap_timeout, snapshot - 1);

		// ============================================
		if (errors) $display("\n%0d FAILURES", errors);
		else $display("\nALL TESTS PASSED");
		$finish;
	end
endmodule
