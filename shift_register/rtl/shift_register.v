`timescale 1ns/1ps
// Universal shift register: hold / shift right / shift left / parallel load
module shift_register #(
    parameter N = 8
)(
    input              clk,
    input              rst,        // synchronous, active-high
    input      [1:0]   mode,       // 00 hold, 01 shift right, 10 shift left, 11 load
    input              sin_left,   // serial input used when shifting left (enters bit 0)
    input              sin_right,  // serial input used when shifting right (enters bit N-1)
    input      [N-1:0] d,          // parallel load data
    output reg [N-1:0] q
);

    always @(posedge clk) begin
        if (rst)
            q <= {N{1'b0}};
        else begin
            case (mode)
                2'b00:   q <= q;
                2'b01:   q <= {sin_right, q[N-1:1]};
                2'b10:   q <= {q[N-2:0], sin_left};
                2'b11:   q <= d;
                default: q <= q;
            endcase
        end
    end

endmodule
