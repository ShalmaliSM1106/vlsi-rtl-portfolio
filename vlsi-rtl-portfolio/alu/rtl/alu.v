`timescale 1ns/1ps
// ALU: combinational arithmetic/logic unit with status flags (Verilog-2001)
module alu #(
    parameter WIDTH = 8
)(
    input      [WIDTH-1:0] a,
    input      [WIDTH-1:0] b,
    input      [3:0]       op,
    output reg [WIDTH-1:0] result,
    output reg             zero,
    output reg             carry,     // ADD: carry out, SUB: borrow (a < b unsigned)
    output reg             overflow,  // signed overflow, ADD/SUB only
    output reg             negative
);

    // Opcodes
    localparam OP_ADD = 4'd0;
    localparam OP_SUB = 4'd1;
    localparam OP_AND = 4'd2;
    localparam OP_OR  = 4'd3;
    localparam OP_XOR = 4'd4;
    localparam OP_NOT = 4'd5;   // ~a
    localparam OP_SLL = 4'd6;   // a << b
    localparam OP_SRL = 4'd7;   // a >> b (logical)
    localparam OP_SLT = 4'd8;   // signed (a < b) ? 1 : 0

    always @(*) begin
        // Defaults: every output assigned, so no latches
        result   = {WIDTH{1'b0}};
        carry    = 1'b0;
        overflow = 1'b0;

        case (op)
            OP_ADD: begin
                {carry, result} = a + b;
                overflow = (a[WIDTH-1] == b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]);
            end
            OP_SUB: begin
                {carry, result} = a - b;
                overflow = (a[WIDTH-1] != b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]);
            end
            OP_AND: result = a & b;
            OP_OR:  result = a | b;
            OP_XOR: result = a ^ b;
            OP_NOT: result = ~a;
            OP_SLL: result = a << b;
            OP_SRL: result = a >> b;
            OP_SLT: result = ($signed(a) < $signed(b)) ? {{(WIDTH-1){1'b0}}, 1'b1}
                                                       : {WIDTH{1'b0}};
            default: result = {WIDTH{1'b0}};
        endcase

        zero     = (result == {WIDTH{1'b0}});
        negative = result[WIDTH-1];
    end

endmodule
