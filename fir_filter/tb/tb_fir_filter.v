`timescale 1ns/1ps
module tb_fir_filter;

    parameter TAPS = 4;
    parameter DW   = 8;
    parameter CW   = 8;
    localparam OW  = DW + CW + $clog2(TAPS);
    localparam LATENCY = 4;

    reg                 clk = 0;
    reg                 rst = 1;
    reg                 in_valid = 0;
    reg  signed [DW-1:0] x_in = 0;
    wire signed [OW-1:0] y_out;
    wire                out_valid;

    fir_filter #(.TAPS(TAPS), .DW(DW), .CW(CW)) dut (
        .clk(clk), .rst(rst), .in_valid(in_valid), .x_in(x_in),
        .y_out(y_out), .out_valid(out_valid)
    );

    always #5 clk = ~clk;

    // ---------------- self-checking infrastructure ----------------
    integer errors = 0;
    task check(input [31:0] got, input [31:0] exp, input [8*20:1] msg);
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL %s: got %h, expected %h", msg, got, exp);
        end
    endtask

    // ---------------- reference model ----------------
    integer hc      [0:TAPS-1];     // coefficients (must match the DUT)
    integer hist    [0:TAPS-1];     // last TAPS valid samples
    integer exp_q   [0:2047];       // expected outputs, one per valid input
    integer out_log [0:2047];       // observed outputs
    integer wr_idx = 0;             // number of valid inputs sent
    integer rd_idx = 0;             // number of valid outputs seen
    integer cyc = 0;
    integer first_in_cyc = 0, first_out_cyc = 0;
    integer k;

    always @(posedge clk) cyc <= cyc + 1;

    // Output monitor: compare ONLY when out_valid is high
    always @(posedge clk) begin
        if (out_valid) begin
            if (rd_idx >= wr_idx) begin
                errors = errors + 1;
                $display("FAIL spurious out_valid at output %0d", rd_idx);
            end else begin
                check(y_out, exp_q[rd_idx], "y_out vs model");
                out_log[rd_idx] = y_out;
                if (rd_idx == 0) first_out_cyc = cyc;
                rd_idx = rd_idx + 1;
            end
        end
    end

    // Drive one cycle (changes inputs on the falling edge to avoid races).
    // When v == 0 the data input is garbage that must be ignored.
    task send(input signed [DW-1:0] x, input v);
        integer s;
        begin
            @(negedge clk);
            in_valid = v;
            if (v) begin
                x_in = x;
                if (wr_idx == 0) first_in_cyc = cyc;
                for (k = TAPS-1; k > 0; k = k - 1) hist[k] = hist[k-1];
                hist[0] = x;
                s = 0;
                for (k = 0; k < TAPS; k = k + 1) s = s + hc[k] * hist[k];
                exp_q[wr_idx] = s;
                wr_idx = wr_idx + 1;
            end else begin
                x_in = $random;
            end
        end
    endtask

    task reset_all;
        begin
            rst = 1; in_valid = 0; x_in = 0;
            wr_idx = 0; rd_idx = 0;
            for (k = 0; k < TAPS; k = k + 1) hist[k] = 0;
            repeat (3) @(negedge clk);
            rst = 0;
            @(negedge clk);
        end
    endtask

    task drain;
        begin
            @(negedge clk); in_valid = 0;
            repeat (LATENCY + 4) @(negedge clk);
            check(rd_idx, wr_idx, "all outputs seen");
        end
    endtask

    integer n;

    initial begin
        // coefficients h = {1, 2, 3, 4}
        hc[0] = 1; hc[1] = 2; hc[2] = 3; hc[3] = 4;

        // ---------- Test 1: impulse -> coefficients in order ----------
        reset_all;
        send(1, 1);
        for (n = 0; n < 7; n = n + 1) send(0, 1);
        drain;
        check(out_log[0], 1, "impulse h0");
        check(out_log[1], 2, "impulse h1");
        check(out_log[2], 3, "impulse h2");
        check(out_log[3], 4, "impulse h3");
        check(out_log[4], 0, "impulse tail");
        check(out_log[7], 0, "impulse tail end");
        check(first_out_cyc - first_in_cyc, LATENCY, "latency");

        // ---------- Test 2: step -> builds up to sum of coeffs ----------
        reset_all;
        for (n = 0; n < 8; n = n + 1) send(1, 1);
        drain;
        check(out_log[0], 1,  "step y0");
        check(out_log[1], 3,  "step y1");
        check(out_log[2], 6,  "step y2");
        check(out_log[3], 10, "step y3");
        check(out_log[7], 10, "step steady");

        // ---------- Test 3: negative / extreme values ----------
        reset_all;
        for (n = 0; n < 12; n = n + 1) send(-128, 1);
        for (n = 0; n < 12; n = n + 1) send((n % 2) ? 127 : -128, 1);
        drain;
        check(out_log[5], -1280, "-128 steady");   // -128 * (1+2+3+4)

        // ---------- Test 4: random data, random valid gaps ----------
        reset_all;
        for (n = 0; n < 300; n = n + 1)
            send($random, ($random & 3) != 0);     // ~75% valid
        drain;

        // ---------- Test 5: random, back-to-back valid ----------
        reset_all;
        for (n = 0; n < 300; n = n + 1) send($random, 1);
        drain;

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule