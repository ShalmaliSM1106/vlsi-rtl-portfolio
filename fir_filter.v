// =============================================================================
// Module      : fir_filter
// Description : 8-Tap Pipelined FIR Filter ? Direct Form I
//               Parameterized data width and coefficient width
//               Fully pipelined ? one output per clock after initial latency
//               Coefficients are symmetric (linear phase FIR)
//
//               Output = sum(coeff[k] * x[n-k]) for k = 0 to 7
//
//               Default coefficients: Low-pass filter
//               h = [-1, 0, 9, 16, 9, 0, -1, 0] (scaled by 32)
//
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module fir_filter #(
    parameter DATA_WIDTH  = 8,
    parameter COEFF_WIDTH = 8,
    parameter NUM_TAPS    = 8
)(
    input  wire                                        clk,
    input  wire                                        reset,
    input  wire signed [DATA_WIDTH-1:0]                x_in,
    input  wire                                        x_valid,

    output reg  signed [DATA_WIDTH+COEFF_WIDTH+2:0]    y_out,
    output reg                                         y_valid
);

// -----------------------------------------------------------------------------
// Coefficients ? Low-pass, symmetric
// h = [-1, 0, 9, 16, 9, 0, -1, 0]
// -----------------------------------------------------------------------------
wire signed [COEFF_WIDTH-1:0] coeff [0:NUM_TAPS-1];
assign coeff[0] = -8'sd1;
assign coeff[1] =  8'sd0;
assign coeff[2] =  8'sd9;
assign coeff[3] =  8'sd16;
assign coeff[4] =  8'sd9;
assign coeff[5] =  8'sd0;
assign coeff[6] = -8'sd1;
assign coeff[7] =  8'sd0;

// -----------------------------------------------------------------------------
// Delay line
// -----------------------------------------------------------------------------
reg signed [DATA_WIDTH-1:0] delay_line [0:NUM_TAPS-1];

// -----------------------------------------------------------------------------
// Pipeline registers
// Stage 1: multiply
// Stage 2: add pairs
// Stage 3: add halves
// Stage 4: final sum ? output
// -----------------------------------------------------------------------------
reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] products     [0:NUM_TAPS-1];
reg signed [DATA_WIDTH+COEFF_WIDTH:0]   partial_sum  [0:NUM_TAPS/2-1];
reg signed [DATA_WIDTH+COEFF_WIDTH+1:0] sum_a, sum_b;

reg valid_s1, valid_s2, valid_s3;

integer i;

// -----------------------------------------------------------------------------
// Stage 0 ? Shift delay line
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < NUM_TAPS; i = i + 1)
            delay_line[i] <= 0;
    end
    else if (x_valid) begin
        delay_line[0] <= x_in;
        for (i = 1; i < NUM_TAPS; i = i + 1)
            delay_line[i] <= delay_line[i-1];
    end
end

// -----------------------------------------------------------------------------
// Stage 1 ? Multiply each tap
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < NUM_TAPS; i = i + 1)
            products[i] <= 0;
        valid_s1 <= 0;
    end
    else begin
        valid_s1 <= x_valid;
        for (i = 0; i < NUM_TAPS; i = i + 1)
            products[i] <= delay_line[i] * coeff[i];
    end
end

// -----------------------------------------------------------------------------
// Stage 2 ? Add pairs
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < NUM_TAPS/2; i = i + 1)
            partial_sum[i] <= 0;
        valid_s2 <= 0;
    end
    else begin
        valid_s2 <= valid_s1;
        for (i = 0; i < NUM_TAPS/2; i = i + 1)
            partial_sum[i] <= products[2*i] + products[2*i+1];
    end
end

// -----------------------------------------------------------------------------
// Stage 3 ? Sum into two halves
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        sum_a    <= 0;
        sum_b    <= 0;
        valid_s3 <= 0;
    end
    else begin
        valid_s3 <= valid_s2;
        sum_a    <= partial_sum[0] + partial_sum[1];
        sum_b    <= partial_sum[2] + partial_sum[3];
    end
end

// -----------------------------------------------------------------------------
// Stage 4 ? Final output
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        y_out   <= 0;
        y_valid <= 0;
    end
    else begin
        y_valid <= valid_s3;
        y_out   <= sum_a + sum_b;
    end
end

endmodule