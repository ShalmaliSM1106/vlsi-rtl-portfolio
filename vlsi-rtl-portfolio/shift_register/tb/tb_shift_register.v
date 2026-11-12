`timescale 1ns/1ps
// Self-checking testbench for shift_register (N = 8)
module tb_shift_register;

    localparam N = 8;

    reg          clk, rst;
    reg  [1:0]   mode;
    reg          sin_left, sin_right;
    reg  [N-1:0] d;
    wire [N-1:0] q;

    shift_register #(.N(N)) dut (
        .clk(clk), .rst(rst), .mode(mode),
        .sin_left(sin_left), .sin_right(sin_right),
        .d(d), .q(q)
    );

    // 10 ns clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    integer errors = 0;
    integer checks = 0;

    task check(input [31:0] got, input [31:0] exp, input [8*20:1] msg);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %s: got %h, expected %h (t=%0t mode=%b)",
                         msg, got, exp, $time, mode);
            end
        end
    endtask

    // Expected copy of q, updated at each rising edge using the same inputs
    reg [N-1:0] exp_q;
    always @(posedge clk) begin
        if (rst)
            exp_q <= {N{1'b0}};
        else begin
            case (mode)
                2'b00: exp_q <= exp_q;
                2'b01: exp_q <= {sin_right, exp_q[N-1:1]};
                2'b10: exp_q <= {exp_q[N-2:0], sin_left};
                2'b11: exp_q <= d;
            endcase
        end
    end

    // Drive inputs on the falling edge, check #1 after the next rising edge
    task step(input [1:0] m, input sl, input sr, input [N-1:0] data);
        begin
            @(negedge clk);
            mode = m; sin_left = sl; sin_right = sr; d = data;
            @(posedge clk);
            #1;
            check(q, exp_q, "q vs expected");
        end
    endtask

    integer i;

    initial begin
        rst = 1'b1; mode = 2'b00; sin_left = 1'b0; sin_right = 1'b0; d = {N{1'b0}};
        exp_q = {N{1'b0}};

        // Reset (checked over two edges)
        step(2'b11, 1'b0, 1'b0, 8'hFF);   // rst has priority over load
        check(q, 8'h00, "reset clears q");
        step(2'b11, 1'b0, 1'b0, 8'hFF);
        check(q, 8'h00, "reset holds clear");

        @(negedge clk);
        rst = 1'b0;

        // Load, then hold for a few clocks
        step(2'b11, 1'b0, 1'b0, 8'hA5);
        check(q, 8'hA5, "load A5");
        for (i = 0; i < 3; i = i + 1) begin
            step(2'b00, 1'b1, 1'b1, 8'h00);
            check(q, 8'hA5, "hold A5");
        end

        // Shift right with sin_right = 1, then 0 (more than N clocks to flush)
        for (i = 0; i < 10; i = i + 1) step(2'b01, 1'b0, 1'b1, 8'h00);
        check(q, 8'hFF, "shr fills with 1s");
        for (i = 0; i < 10; i = i + 1) step(2'b01, 1'b0, 1'b0, 8'h00);
        check(q, 8'h00, "shr fills with 0s");

        // Shift left with a pattern on sin_left
        step(2'b11, 1'b0, 1'b0, 8'h01);
        for (i = 0; i < 4; i = i + 1) step(2'b10, i[0], 1'b0, 8'h00);
        check(q, 8'h15, "shl pattern");     // 0000_0001 <- 0,1,0,1 = 0001_0101
        for (i = 0; i < 10; i = i + 1) step(2'b10, 1'b0, 1'b1, 8'h00);
        check(q, 8'h00, "shl flush");

        // Mode changes back to back, mixed serial inputs
        step(2'b11, 1'b0, 1'b0, 8'h96);
        step(2'b01, 1'b1, 1'b1, 8'h00);
        step(2'b10, 1'b1, 1'b0, 8'h00);
        step(2'b00, 1'b0, 1'b0, 8'h00);
        step(2'b10, 1'b0, 1'b1, 8'h00);
        step(2'b01, 1'b1, 1'b0, 8'h00);
        step(2'b11, 1'b1, 1'b1, 8'h3C);
        check(q, 8'h3C, "load 3C");

        // Mid-operation reset
        @(negedge clk);
        rst = 1'b1; mode = 2'b01; sin_right = 1'b1;
        @(posedge clk); #1;
        check(q, 8'h00, "mid reset");
        check(q, exp_q, "mid reset vs exp");
        @(negedge clk);
        rst = 1'b0;

        // Random stimulus
        for (i = 0; i < 500; i = i + 1)
            step($random, $random, $random, $random);

        $display("Ran %0d checks", checks);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule