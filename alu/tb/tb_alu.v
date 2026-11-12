`timescale 1ns/1ps
// Exhaustive self-checking testbench for alu, WIDTH = 4
module tb_alu;

    localparam WIDTH = 4;

    reg  [WIDTH-1:0] a, b;
    reg  [3:0]       op;
    wire [WIDTH-1:0] result;
    wire             zero, carry, overflow, negative;

    alu #(.WIDTH(WIDTH)) dut (
        .a(a), .b(b), .op(op),
        .result(result), .zero(zero), .carry(carry),
        .overflow(overflow), .negative(negative)
    );

    integer errors = 0;
    integer checks = 0;

    task check(input [31:0] got, input [31:0] exp, input [8*20:1] msg);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %s: got %h, expected %h (op=%0d a=%0d b=%0d)",
                         msg, got, exp, op, a, b);
            end
        end
    endtask

    // Expected-value model using ordinary Verilog operators
    reg [WIDTH-1:0] e_res;
    reg             e_carry, e_ovf;
    reg [WIDTH:0]   e_wide;
    integer         e_sa, e_sb, e_sr;   // signed values for overflow check

    task compute_expected;
        begin
            e_carry = 1'b0;
            e_ovf   = 1'b0;
            e_res   = {WIDTH{1'b0}};
            e_wide  = {(WIDTH+1){1'b0}};
            // signed interpretation of a and b
            e_sa = a[WIDTH-1] ? (a - (1 << WIDTH)) : a;
            e_sb = b[WIDTH-1] ? (b - (1 << WIDTH)) : b;
            case (op)
                4'd0: begin
                    e_wide  = a + b;
                    e_res   = e_wide[WIDTH-1:0];
                    e_carry = e_wide[WIDTH];
                    e_sr    = e_sa + e_sb;
                    e_ovf   = (e_sr > (1 << (WIDTH-1)) - 1) || (e_sr < -(1 << (WIDTH-1)));
                end
                4'd1: begin
                    e_wide  = a - b;
                    e_res   = e_wide[WIDTH-1:0];
                    e_carry = e_wide[WIDTH];
                    e_sr    = e_sa - e_sb;
                    e_ovf   = (e_sr > (1 << (WIDTH-1)) - 1) || (e_sr < -(1 << (WIDTH-1)));
                end
                4'd2: e_res = a & b;
                4'd3: e_res = a | b;
                4'd4: e_res = a ^ b;
                4'd5: e_res = ~a;
                4'd6: e_res = a << b;
                4'd7: e_res = a >> b;
                4'd8: e_res = (e_sa < e_sb) ? 1 : 0;
                default: e_res = {WIDTH{1'b0}};
            endcase
        end
    endtask

    integer i, j, k;

    initial begin
        for (k = 0; k < 16; k = k + 1) begin
            for (i = 0; i < (1 << WIDTH); i = i + 1) begin
                for (j = 0; j < (1 << WIDTH); j = j + 1) begin
                    op = k[3:0];
                    a  = i[WIDTH-1:0];
                    b  = j[WIDTH-1:0];
                    #1;
                    compute_expected;
                    check(result,   e_res,                 "result");
                    check(zero,     (e_res == 0),          "zero");
                    check(negative, e_res[WIDTH-1],        "negative");
                    check(carry,    e_carry,               "carry");
                    check(overflow, e_ovf,                 "overflow");
                end
            end
        end

        $display("Ran %0d checks", checks);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule
