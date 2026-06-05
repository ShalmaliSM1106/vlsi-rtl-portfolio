// =============================================================================
// Module      : tb_universal_shift_register
// Description : Exhaustive testbench for Universal Shift Register
//               Tests all 4 modes, reset, enable, and serial I/O behavior
//               Self-checking with PASS/FAIL summary
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

`timescale 1ns/1ps

module tb_universal_shift_register;

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------
parameter N        = 8;
parameter CLK_PERIOD = 10; // 10ns = 100MHz

// -----------------------------------------------------------------------------
// DUT I/O
// -----------------------------------------------------------------------------
reg         clk;
reg         reset;
reg         enable;
reg  [1:0]  mode;
reg  [N-1:0] parallel_in;
reg         serial_in_right;
reg         serial_in_left;

wire [N-1:0] q;
wire         serial_out_right;
wire         serial_out_left;

// -----------------------------------------------------------------------------
// Instantiate DUT
// -----------------------------------------------------------------------------
universal_shift_register #(.N(N)) dut (
    .clk             (clk),
    .reset           (reset),
    .enable          (enable),
    .mode            (mode),
    .parallel_in     (parallel_in),
    .serial_in_right (serial_in_right),
    .serial_in_left  (serial_in_left),
    .q               (q),
    .serial_out_right(serial_out_right),
    .serial_out_left (serial_out_left)
);

// -----------------------------------------------------------------------------
// Clock Generation
// -----------------------------------------------------------------------------
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// -----------------------------------------------------------------------------
// Test Counters
// -----------------------------------------------------------------------------
integer pass_count;
integer fail_count;
integer total;

// -----------------------------------------------------------------------------
// Task: apply_and_check
// Applies inputs, waits one clock, checks output
// -----------------------------------------------------------------------------
task apply_and_check;
    input [N-1:0]  exp_q;
    input          exp_sor; // expected serial_out_right
    input          exp_sol; // expected serial_out_left
    input [63:0]   test_id;
    begin
        @(posedge clk); #1; // sample just after clock edge
        if (q !== exp_q || serial_out_right !== exp_sor || serial_out_left !== exp_sol) begin
            $display("FAIL [Test %0d] | Got q=%b sor=%b sol=%b | Exp q=%b sor=%b sol=%b",
                test_id, q, serial_out_right, serial_out_left,
                exp_q, exp_sor, exp_sol);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
        total = total + 1;
    end
endtask

// -----------------------------------------------------------------------------
// Main Test Sequence
// -----------------------------------------------------------------------------
initial begin
    // Initialise
    reset          = 1;
    enable         = 0;
    mode           = 2'b00;
    parallel_in    = {N{1'b0}};
    serial_in_right = 0;
    serial_in_left  = 0;
    pass_count     = 0;
    fail_count     = 0;
    total          = 0;

    $display("=============================================================");
    $display("  Universal Shift Register Testbench  |  N = %0d bits", N);
    $display("=============================================================");

    // ------------------------------------------------------------------
    // Test 1: Synchronous Reset
    // ------------------------------------------------------------------
    $display("--- Test 1: Synchronous Reset ---");
    reset  = 1;
    enable = 1;
    @(posedge clk); #1;
    apply_and_check({N{1'b0}}, 1'b0, 1'b0, 1);
    reset = 0;

    // ------------------------------------------------------------------
    // Test 2: Parallel Load
    // ------------------------------------------------------------------
    $display("--- Test 2: Parallel Load ---");
    mode        = 2'b11;
    enable      = 1;
    parallel_in = 8'b10110101;
    apply_and_check(8'b10110101, 1'b1, 1'b1, 2);

    parallel_in = 8'b00001111;
    apply_and_check(8'b00001111, 1'b1, 1'b0, 3);

    parallel_in = 8'b11110000;
    apply_and_check(8'b11110000, 1'b0, 1'b1, 4);

    parallel_in = 8'b00000000;
    apply_and_check(8'b00000000, 1'b0, 1'b0, 5);

    parallel_in = 8'b11111111;
    apply_and_check(8'b11111111, 1'b1, 1'b1, 6);

    // ------------------------------------------------------------------
    // Test 3: Shift Right (serial_in_right = 0)
    // Load 8'b10110101 then shift right 8 times with 0 input
    // ------------------------------------------------------------------
    $display("--- Test 3: Shift Right (serial_in=0) ---");
    mode            = 2'b11;
    parallel_in     = 8'b10110101;
    apply_and_check(8'b10110101, 1'b1, 1'b1, 7);

    mode            = 2'b01;
    serial_in_right = 0;
    apply_and_check(8'b01011010, 1'b0, 1'b0, 8);
    apply_and_check(8'b00101101, 1'b1, 1'b0, 9);
    apply_and_check(8'b00010110, 1'b0, 1'b0, 10);
    apply_and_check(8'b00001011, 1'b1, 1'b0, 11);
    apply_and_check(8'b00000101, 1'b1, 1'b0, 12);
    apply_and_check(8'b00000010, 1'b0, 1'b0, 13);
    apply_and_check(8'b00000001, 1'b1, 1'b0, 14);
    apply_and_check(8'b00000000, 1'b0, 1'b0, 15);

    // ------------------------------------------------------------------
    // Test 4: Shift Right (serial_in_right = 1)
    // Load 0 then shift in 1s from the right
    // ------------------------------------------------------------------
    $display("--- Test 4: Shift Right (serial_in=1) ---");
    mode        = 2'b11;
    parallel_in = 8'b00000000;
    apply_and_check(8'b00000000, 1'b0, 1'b0, 16);

    mode            = 2'b01;
    serial_in_right = 1;
    apply_and_check(8'b10000000, 1'b0, 1'b1, 17);
    apply_and_check(8'b11000000, 1'b0, 1'b1, 18);
    apply_and_check(8'b11100000, 1'b0, 1'b1, 19);
    apply_and_check(8'b11110000, 1'b0, 1'b1, 20);
    apply_and_check(8'b11111000, 1'b0, 1'b1, 21);
    apply_and_check(8'b11111100, 1'b0, 1'b1, 22);
    apply_and_check(8'b11111110, 1'b0, 1'b1, 23);
    apply_and_check(8'b11111111, 1'b1, 1'b1, 24);

    // ------------------------------------------------------------------
    // Test 5: Shift Left (serial_in_left = 0)
    // Load 8'b10110101 then shift left with 0 input
    // ------------------------------------------------------------------
    $display("--- Test 5: Shift Left (serial_in=0) ---");
    mode        = 2'b11;
    parallel_in = 8'b10110101;
    apply_and_check(8'b10110101, 1'b1, 1'b1, 25);

    mode           = 2'b10;
    serial_in_left = 0;
    apply_and_check(8'b01101010, 1'b0, 1'b0, 26);
    apply_and_check(8'b11010100, 1'b0, 1'b1, 27);
    apply_and_check(8'b10101000, 1'b0, 1'b1, 28);
    apply_and_check(8'b01010000, 1'b0, 1'b0, 29);
    apply_and_check(8'b10100000, 1'b0, 1'b1, 30);
    apply_and_check(8'b01000000, 1'b0, 1'b0, 31);
    apply_and_check(8'b10000000, 1'b0, 1'b1, 32);
    apply_and_check(8'b00000000, 1'b0, 1'b0, 33);

    // ------------------------------------------------------------------
    // Test 6: Hold Mode
    // ------------------------------------------------------------------
    $display("--- Test 6: Hold Mode ---");
    mode        = 2'b11;
    parallel_in = 8'b10101010;
    apply_and_check(8'b10101010, 1'b0, 1'b1, 34);

    mode = 2'b00;
    apply_and_check(8'b10101010, 1'b0, 1'b1, 35);
    apply_and_check(8'b10101010, 1'b0, 1'b1, 36);
    apply_and_check(8'b10101010, 1'b0, 1'b1, 37);

    // ------------------------------------------------------------------
    // Test 7: Enable = 0 (register should not change)
    // ------------------------------------------------------------------
    $display("--- Test 7: Enable Disabled ---");
    mode        = 2'b11;
    enable      = 1;
    parallel_in = 8'b11001100;
    apply_and_check(8'b11001100, 1'b0, 1'b1, 38);

    enable = 0;
    mode   = 2'b01; // try to shift right ? should not change
    apply_and_check(8'b11001100, 1'b0, 1'b1, 39);
    apply_and_check(8'b11001100, 1'b0, 1'b1, 40);

    // ------------------------------------------------------------------
    // Test 8: Reset overrides everything
    // ------------------------------------------------------------------
    $display("--- Test 8: Reset Override ---");
    enable = 1;
    mode   = 2'b11;
    parallel_in = 8'b11111111;
    apply_and_check(8'b11111111, 1'b1, 1'b1, 41);

    reset = 1;
    apply_and_check(8'b00000000, 1'b0, 1'b0, 42);
    reset = 0;

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
    $display("=============================================================");
    $display("  TEST SUMMARY");
    $display("  Total  : %0d", total);
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    if (fail_count == 0)
        $display("  STATUS : ALL TESTS PASSED");
    else
        $display("  STATUS : SOME TESTS FAILED ? review output above");
    $display("=============================================================");

    $finish;
end

endmodule