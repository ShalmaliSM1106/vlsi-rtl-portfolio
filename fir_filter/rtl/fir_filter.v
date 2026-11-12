`timescale 1ns/1ps
// Pipelined FIR filter: y[n] = h0*x[n] + h1*x[n-1] + h2*x[n-2] + ...
// Fixed coefficients h = {1, 2, 3, 4}. Synchronous, active-high reset.
//
// Pipeline (latency = 4 clocks from the edge that samples in_valid/x_in
// to the edge after which out_valid/y_out are visible):
//   stage 0 : shift register of the last TAPS samples (only shifts when in_valid)
//   stage 1 : products  prod[i] = x_sr[i] * h[i]
//   stage 2 : pair sums sum2[k] = prod[2k] + prod[2k+1]
//   stage 3 : y_out     = sum of the pair sums
// in_valid travels down a shift register of the same depth -> out_valid.
//
// Note: the pair-adder structure assumes TAPS is even (default 4).
module fir_filter #(
    parameter TAPS = 4,
    parameter DW   = 8,     // input sample width (signed)
    parameter CW   = 8      // coefficient width (signed)
)(
    input                               clk,
    input                               rst,
    input                               in_valid,
    input  signed [DW-1:0]              x_in,
    output reg signed [DW+CW+$clog2(TAPS)-1:0] y_out,
    output                              out_valid
);

    localparam PW = DW + CW;                 // product width
    localparam SW = DW + CW + 1;             // pair-sum width
    localparam OW = DW + CW + $clog2(TAPS);  // output width (no overflow)
    localparam LATENCY = 4;

    // Fixed coefficients: h0=1, h1=2, h2=3, h3=4 (others 0)
    function signed [CW-1:0] coeff(input integer idx);
        begin
            case (idx)
                0:       coeff = 1;
                1:       coeff = 2;
                2:       coeff = 3;
                3:       coeff = 4;
                default: coeff = 0;
            endcase
        end
    endfunction

    reg signed [DW-1:0] x_sr  [0:TAPS-1];     // stage 0
    reg signed [PW-1:0] prod  [0:TAPS-1];     // stage 1
    reg signed [SW-1:0] sum2  [0:TAPS/2-1];   // stage 2
    reg signed [OW-1:0] sum3;                 // stage 3 adder (combinational)
    reg [LATENCY-1:0]   vpipe;                // valid pipeline

    integer i, j;

    initial begin
        if (TAPS < 2 || (TAPS % 2) != 0)
            $display("fir_filter ERROR: TAPS must be even and >= 2");
    end

    // Stage 3 adder: sum of all pair sums (combinational, default first)
    always @(*) begin
        sum3 = {OW{1'b0}};
        for (j = 0; j < TAPS/2; j = j + 1)
            sum3 = sum3 + sum2[j];
    end

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < TAPS; i = i + 1) begin
                x_sr[i] <= {DW{1'b0}};
                prod[i] <= {PW{1'b0}};
            end
            for (i = 0; i < TAPS/2; i = i + 1)
                sum2[i] <= {SW{1'b0}};
            y_out <= {OW{1'b0}};
            vpipe <= {LATENCY{1'b0}};
        end else begin
            // stage 0: shift in a new sample only when valid
            if (in_valid) begin
                x_sr[0] <= x_in;
                for (i = 1; i < TAPS; i = i + 1)
                    x_sr[i] <= x_sr[i-1];
            end
            // stage 1: multiply (signed * signed)
            for (i = 0; i < TAPS; i = i + 1)
                prod[i] <= x_sr[i] * coeff(i);
            // stage 2: add in pairs
            for (i = 0; i < TAPS/2; i = i + 1)
                sum2[i] <= prod[2*i] + prod[2*i+1];
            // stage 3: add the pairs
            y_out <= sum3;
            // valid pipeline, same depth as the data path
            vpipe <= {vpipe[LATENCY-2:0], in_valid};
        end
    end

    assign out_valid = vpipe[LATENCY-1];

endmodule
