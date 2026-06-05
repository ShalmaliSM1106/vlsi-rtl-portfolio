// =============================================================================
// Module      : universal_shift_register
// Description : Parameterized N-bit Universal Shift Register
//               Supports 4 modes:
//               00 - Hold (retain current value)
//               01 - Shift Right (MSB filled with serial_in_right)
//               10 - Shift Left  (LSB filled with serial_in_left)
//               11 - Parallel Load
//               Synchronous reset, active high enable
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module universal_shift_register #(
    parameter N = 8          // Bit width ? default 8, scalable
)(
    input  wire         clk,             // Clock
    input  wire         reset,           // Synchronous reset, active high
    input  wire         enable,          // Enable signal, active high
    input  wire [1:0]   mode,            // Mode select
    input  wire [N-1:0] parallel_in,     // Parallel load data
    input  wire         serial_in_right, // Serial input for right shift (fed into MSB)
    input  wire         serial_in_left,  // Serial input for left shift  (fed into LSB)

    output reg  [N-1:0] q,               // Register output
    output wire         serial_out_right,// Serial output ? LSB (right shift output)
    output wire         serial_out_left  // Serial output ? MSB (left shift output)
);

// -----------------------------------------------------------------------------
// Mode Definitions
// -----------------------------------------------------------------------------
localparam HOLD          = 2'b00;
localparam SHIFT_RIGHT   = 2'b01;
localparam SHIFT_LEFT    = 2'b10;
localparam PARALLEL_LOAD = 2'b11;

// -----------------------------------------------------------------------------
// Serial outputs ? always driven from register ends
// -----------------------------------------------------------------------------
assign serial_out_right = q[0];     // LSB shifts out on right shift
assign serial_out_left  = q[N-1];   // MSB shifts out on left shift

// -----------------------------------------------------------------------------
// Sequential Logic
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        q <= {N{1'b0}};
    end
    else if (enable) begin
        case (mode)
            HOLD:          q <= q;
            SHIFT_RIGHT:   q <= {serial_in_right, q[N-1:1]};  // Shift right, fill MSB
            SHIFT_LEFT:    q <= {q[N-2:0], serial_in_left};   // Shift left, fill LSB
            PARALLEL_LOAD: q <= parallel_in;
            default:       q <= q;
        endcase
    end
end

endmodule