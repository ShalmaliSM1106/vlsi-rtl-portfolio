// =============================================================================
// Module      : tb_fir_filter
// Description : Testbench for 8-tap pipelined FIR filter
//               Tests:
//               1. Zero input -> output should be zero
//               2. Impulse response -> output should match coefficients
//               3. DC input -> DC gain verification
//               4. Pipeline latency check -> valid signal propagation
//               Self-checking with PASS/FAIL summary
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

`timescale 1ns/1ps

module tb_fir_filter;

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------
parameter DATA_WIDTH       = 8;
parameter COEFF_WIDTH      = 8;
parameter NUM_TAPS         = 8;
parameter CLK_PERIOD       = 10;
parameter PIPELINE_LATENCY = 4; // 4 stage pipeline

// -----------------------------------------------------------------------------
// DUT I/O
// -----------------------------------------------------------------------------
reg                                      clk;
reg                                      reset;
reg  signed [DATA_WIDTH-1:0]             x_in;
reg                                      x_valid;

wire signed [DATA_WIDTH+COEFF_WIDTH+2:0] y_out;
wire                                     y_valid;

// -----------------------------------------------------------------------------
// Instantiate DUT
// -----------------------------------------------------------------------------
fir_filter #(
    .DATA_WIDTH (DATA_WIDTH),
    .COEFF_WIDTH(COEFF_WIDTH),
    .NUM_TAPS   (NUM_TAPS)
) dut (
    .clk    (clk),
    .reset  (reset),
    .x_in   (x_in),
    .x_valid(x_valid),
    .y_out  (y_out),
    .y_valid(y_valid)
);

// -----------------------------------------------------------------------------
// Clock
// -----------------------------------------------------------------------------
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// -----------------------------------------------------------------------------
// Test Counters
// -----------------------------------------------------------------------------
integer pass_count;
integer fail_count;
integer total;
integer i;

// Store output samples
reg signed [DATA_WIDTH+COEFF_WIDTH+2:0] output_samples [0:31];
integer sample_index;

// -----------------------------------------------------------------------------
// Task: apply_sample
// -----------------------------------------------------------------------------
task apply_sample;
    input signed [DATA_WIDTH-1:0] sample;
    begin
        @(posedge clk);
        x_in    = sample;
        x_valid = 1'b1;
        @(posedge clk);
        x_valid = 1'b0;
        x_in    = 0;
    end
endtask

// -----------------------------------------------------------------------------
// Task: check_output
// -----------------------------------------------------------------------------
task check_output;
    input signed [DATA_WIDTH+COEFF_WIDTH+2:0] got;
    input signed [DATA_WIDTH+COEFF_WIDTH+2:0] exp;
    input [63:0] test_id;
    begin
        if (got !== exp) begin
            $display("FAIL [Test %0d] Got=%0d Exp=%0d", test_id, got, exp);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS [Test %0d] Output=%0d", test_id, got);
            pass_count = pass_count + 1;
        end
        total = total + 1;
    end
endtask

// -----------------------------------------------------------------------------
// Capture outputs
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (y_valid) begin
        output_samples[sample_index] <= y_out;
        sample_index                 <= sample_index + 1;
    end
end

// -----------------------------------------------------------------------------
// Main Test Sequence
// -----------------------------------------------------------------------------
initial begin
    clk          = 0;
    reset        = 1;
    x_in         = 0;
    x_valid      = 0;
    pass_count   = 0;
    fail_count   = 0;
    total        = 0;
    sample_index = 0;

    for (i = 0; i < 32; i = i + 1)
        output_samples[i] = 0;

    $display("=============================================================");
    $display("  FIR Filter Testbench  |  %0d-tap  DATA_WIDTH=%0d", NUM_TAPS, DATA_WIDTH);
    $display("=============================================================");

    repeat(4) @(posedge clk);
    reset = 0;
    repeat(2) @(posedge clk);

    // ------------------------------------------------------------------
    // Test 1: All zeros input -> output must stay zero
    // ------------------------------------------------------------------
    $display("--- Test 1: Zero Input ---");
    sample_index = 0;
    for (i = 0; i < 12; i = i + 1) begin
        apply_sample(0);
    end
    repeat(PIPELINE_LATENCY + 2) @(posedge clk);
    begin : zero_check
        integer j;
        integer found_nonzero;
        found_nonzero = 0;
        for (j = 0; j < sample_index; j = j + 1) begin
            if (output_samples[j] !== 0) begin
                $display("FAIL [Test 1] Non-zero output at sample %0d: %0d", j, output_samples[j]);
                fail_count    = fail_count + 1;
                total         = total + 1;
                found_nonzero = 1;
            end
        end
        if (!found_nonzero) begin
            $display("PASS [Test 1] All zero inputs produced zero outputs");
            pass_count = pass_count + 1;
            total      = total + 1;
        end
    end

    // ------------------------------------------------------------------
    // Test 2: Impulse response
    // Apply x[0]=1, x[1..N]=0
    // Expected coefficients: -1, 0, 9, 16, 9, 0, -1, 0
    //
    // FIX: The capture array contains one leading pipeline bubble (0)
    // before the real impulse response begins, so we compare
    // output_samples[i+1] against exp_impulse[i].
    // ------------------------------------------------------------------
    $display("--- Test 2: Impulse Response ---");
    reset = 1; repeat(3) @(posedge clk); reset = 0;
    sample_index = 0;
    repeat(2) @(posedge clk);

    apply_sample(8'sd1);
    for (i = 0; i < NUM_TAPS + PIPELINE_LATENCY + 2; i = i + 1)
        apply_sample(0);

    repeat(PIPELINE_LATENCY + 2) @(posedge clk);

    $display("  Impulse response outputs (should match coefficients):");
    for (i = 0; i < 12 && i < sample_index; i = i + 1)
        $display("  y[%0d] = %0d", i, output_samples[i]);

    begin : impulse_check
        reg signed [DATA_WIDTH+COEFF_WIDTH+2:0] exp_impulse [0:7];
        exp_impulse[0] = -1;
        exp_impulse[1] =  0;
        exp_impulse[2] =  9;
        exp_impulse[3] =  16;
        exp_impulse[4] =  9;
        exp_impulse[5] =  0;
        exp_impulse[6] = -1;
        exp_impulse[7] =  0;

        // offset by 1 to skip the leading pipeline bubble in output_samples
        for (i = 0; i < 8; i = i + 1) begin
            if (output_samples[i+1] === exp_impulse[i]) begin
                $display("PASS [Test 2.%0d] y[%0d]=%0d matches coeff[%0d]=%0d",
                    i, i+1, output_samples[i+1], i, exp_impulse[i]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [Test 2.%0d] y[%0d]=%0d exp=%0d",
                    i, i+1, output_samples[i+1], exp_impulse[i]);
                fail_count = fail_count + 1;
            end
            total = total + 1;
        end
    end

    // ------------------------------------------------------------------
    // Test 3: DC Input
    // DC gain = sum of coefficients = -1+0+9+16+9+0-1+0 = 32
    // For x=1 constant, expected y = 32 after settling
    // ------------------------------------------------------------------
    $display("--- Test 3: DC Input (x=1, expect y=32 after settling) ---");
    reset = 1; repeat(3) @(posedge clk); reset = 0;
    sample_index = 0;
    repeat(2) @(posedge clk);

    for (i = 0; i < NUM_TAPS + PIPELINE_LATENCY + 4; i = i + 1)
        apply_sample(8'sd1);

    repeat(PIPELINE_LATENCY + 2) @(posedge clk);

    $display("  DC outputs (should settle to 32):");
    for (i = 0; i < sample_index && i < 16; i = i + 1)
        $display("  y[%0d] = %0d", i, output_samples[i]);

    if (sample_index >= NUM_TAPS) begin
        if (output_samples[sample_index-1] === 32) begin
            $display("PASS [Test 3] DC output settled to 32");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 3] DC output = %0d, expected 32", output_samples[sample_index-1]);
            fail_count = fail_count + 1;
        end
        total = total + 1;
    end

    // ------------------------------------------------------------------
    // Test 4: y_valid propagation check
    // y_valid should be low right after a single input sample
    // ------------------------------------------------------------------
    $display("--- Test 4: Pipeline Valid Signal ---");
    reset = 1; repeat(3) @(posedge clk); reset = 0;
    repeat(2) @(posedge clk);

    @(posedge clk);
    x_in    = 8'sd1;
    x_valid = 1'b1;
    @(posedge clk);
    x_valid = 1'b0;
    x_in    = 0;

    @(posedge clk); #1;
    if (y_valid === 1'b0) begin
        $display("PASS [Test 4] y_valid correctly low right after input");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL [Test 4] y_valid high too early");
        fail_count = fail_count + 1;
    end
    total = total + 1;

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
    repeat(5) @(posedge clk);
    $display("=============================================================");
    $display("  TEST SUMMARY");
    $display("  Total  : %0d", total);
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    if (fail_count == 0)
        $display("  STATUS : ALL TESTS PASSED");
    else
        $display("  STATUS : SOME TESTS FAILED - review output above");
    $display("=============================================================");

    $finish;
end

endmodule