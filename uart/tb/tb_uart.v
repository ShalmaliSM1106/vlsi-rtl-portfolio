`timescale 1ns/1ps
// Self-checking testbench: TX -> RX loopback, independent TX frame monitor,
// plus a second RX driven asynchronously to test glitch and framing-error handling.
module tb_uart;

    localparam CPB    = 16;            // short bit time for simulation
    localparam CLK_NS = 10;
    localparam BIT_NS = CPB * CLK_NS;

    reg        clk, rst, tx_start;
    reg  [7:0] tx_data;
    wire       tx, tx_busy;
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_tx #(.CLKS_PER_BIT(CPB)) u_tx (
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy));

    // Loopback: RX input is the TX output
    uart_rx #(.CLKS_PER_BIT(CPB)) u_rx (
        .clk(clk), .rst(rst), .rx(tx), .rx_data(rx_data), .rx_valid(rx_valid));

    // Second receiver, driven by the testbench
    reg        rx2_in;
    wire [7:0] rx2_data;
    wire       rx2_valid;
    uart_rx #(.CLKS_PER_BIT(CPB)) u_rx2 (
        .clk(clk), .rst(rst), .rx(rx2_in), .rx_data(rx2_data), .rx_valid(rx2_valid));

    initial clk = 1'b0;
    always #(CLK_NS/2) clk = ~clk;

    integer errors = 0;
    integer checks = 0;

    task check(input [31:0] got, input [31:0] exp, input [8*20:1] msg);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %s: got %h, expected %h (t=%0t)", msg, got, exp, $time);
            end
        end
    endtask

    // ---------- Monitors ----------
    integer rx_cnt = 0, rx2_cnt = 0;
    reg [7:0] rx2_last = 8'h00;
    reg       rv_d = 1'b0;

    always @(posedge clk) begin
        rv_d <= rx_valid;
        if (rx_valid) rx_cnt = rx_cnt + 1;
        check({31'b0, rx_valid & rv_d}, 0, "rx_valid 1 clk wide");
        if (rx2_valid) begin
            rx2_cnt  = rx2_cnt + 1;
            rx2_last = rx2_data;
        end
    end

    // Independent check of the TX waveform: sample in the middle of each bit
    reg [7:0] exp_byte = 8'h00;
    reg [7:0] mon_byte;
    reg       mon_start, mon_stop;
    integer   mon_frames = 0;
    integer   mk;

    always @(negedge tx) begin
        repeat (CPB/2) @(posedge clk);
        #1 mon_start = tx;
        for (mk = 0; mk < 8; mk = mk + 1) begin
            repeat (CPB) @(posedge clk);
            #1 mon_byte[mk] = tx;
        end
        repeat (CPB) @(posedge clk);
        #1 mon_stop = tx;
        mon_frames = mon_frames + 1;
        check(mon_start, 0,        "start bit is 0");
        check(mon_byte,  exp_byte, "tx frame LSB first");
        check(mon_stop,  1,        "stop bit is 1");
    end

    // ---------- Tasks ----------
    integer sent = 0;

    // Send one byte through the loopback and check what comes out.
    // poke = 1 also pulses tx_start mid-frame (must be ignored while busy).
    task send_byte(input [7:0] b, input poke);
        integer t;
        reg     got;
        begin
            while (tx_busy) @(negedge clk);
            @(negedge clk);
            tx_data = b; tx_start = 1'b1; exp_byte = b; sent = sent + 1;
            @(negedge clk);
            tx_start = 1'b0;
            check(tx_busy, 1, "busy after start");
            if (poke) begin
                repeat (3*CPB + 5) @(negedge clk);
                tx_data = 8'hEE; tx_start = 1'b1;
                @(negedge clk);
                tx_start = 1'b0;
            end
            got = 1'b0; t = 0;
            while (!got && t < 20*CPB) begin
                @(posedge clk); #1;
                t = t + 1;
                if (rx_valid) begin
                    got = 1'b1;
                    check(rx_data, b, "rx_data == sent");
                end
            end
            check(got, 1, "rx_valid seen");
            while (tx_busy) @(negedge clk);
            repeat (2) @(negedge clk);
        end
    endtask

    // Drive rx2_in with a frame, offset from the clock edges (asynchronous to clk)
    task send_raw(input [7:0] b, input stop_bit);
        integer k;
        begin
            @(negedge clk); #3;
            rx2_in = 1'b0;                 #(BIT_NS);
            for (k = 0; k < 8; k = k + 1) begin
                rx2_in = b[k];             #(BIT_NS);
            end
            rx2_in = stop_bit;             #(BIT_NS);
            rx2_in = 1'b1;                 #(BIT_NS);
        end
    endtask

    integer i, n;

    initial begin
        #20_000_000;
        $display("TIMEOUT");
        errors = errors + 1;
        $display("%0d TESTS FAILED", errors);
        $finish;
    end

    initial begin
        rst = 1'b1; tx_start = 1'b0; tx_data = 8'h00; rx2_in = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (3) @(negedge clk);

        check(tx, 1,       "tx idle high");
        check(tx_busy, 0,  "not busy at idle");
        check(rx_valid, 0, "no valid at idle");

        // Directed bytes
        send_byte(8'h00, 0);
        send_byte(8'hFF, 0);
        send_byte(8'h55, 0);
        send_byte(8'hA5, 0);

        // tx_start while busy is ignored
        send_byte(8'h96, 1);

        // 20 random bytes
        for (i = 0; i < 20; i = i + 1)
            send_byte($random, 0);

        repeat (3*CPB) @(negedge clk);
        check(rx_cnt,     sent, "rx bytes == sent");
        check(mon_frames, sent, "tx frames == sent");

        // ---- Second RX: asynchronous input, glitch and framing error ----
        n = rx2_cnt;
        send_raw(8'h3C, 1'b1);
        check(rx2_cnt, n + 1,  "rx2 good byte");
        check(rx2_last, 8'h3C, "rx2 data 3C");

        n = rx2_cnt;
        @(negedge clk); #3;                 // glitch: low for 3 clocks, well under half a bit
        rx2_in = 1'b0; #(3*CLK_NS); rx2_in = 1'b1;
        #(2*BIT_NS);
        check(rx2_cnt, n, "glitch ignored");

        n = rx2_cnt;
        send_raw(8'hC3, 1'b0);              // bad stop bit
        check(rx2_cnt, n, "bad stop dropped");

        n = rx2_cnt;
        send_raw(8'h81, 1'b1);              // receiver must recover
        check(rx2_cnt, n + 1,  "rx2 recovers");
        check(rx2_last, 8'h81, "rx2 data 81");

        $display("Ran %0d checks, %0d bytes via loopback", checks, sent);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule