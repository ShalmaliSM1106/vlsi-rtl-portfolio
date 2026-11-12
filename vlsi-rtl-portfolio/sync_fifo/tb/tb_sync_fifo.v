`timescale 1ns/1ps
// Self-checking testbench for sync_fifo (WIDTH = 8, DEPTH = 16)
module tb_sync_fifo;

    localparam WIDTH = 8;
    localparam DEPTH = 16;

    reg              clk, rst, wr_en, rd_en;
    reg  [WIDTH-1:0] din;
    wire [WIDTH-1:0] dout;
    wire             full, empty;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .din(din),
        .rd_en(rd_en), .dout(dout), .full(full), .empty(empty)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

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

    // ---------------- Reference model: queue with its own pointers ----------------
    reg [WIDTH-1:0] m_mem [0:DEPTH-1];
    reg [WIDTH-1:0] m_dout;
    integer         m_count, m_rp, m_wp;

    always @(posedge clk) begin : model
        reg do_wr, do_rd;
        if (rst) begin
            m_count = 0; m_rp = 0; m_wp = 0; m_dout = {WIDTH{1'b0}};
        end else begin
            do_wr = wr_en && (m_count < DEPTH);
            do_rd = rd_en && (m_count > 0);
            if (do_rd) begin
                m_dout = m_mem[m_rp];
                m_rp   = (m_rp + 1) % DEPTH;
            end
            if (do_wr) begin
                m_mem[m_wp] = din;
                m_wp        = (m_wp + 1) % DEPTH;
            end
            m_count = m_count + do_wr - do_rd;
        end
    end

    // ---------------- Helpers ----------------
    // Drive inputs on the falling edge, check #1 after the next rising edge
    task cycle(input wr, input rd, input [WIDTH-1:0] data);
        begin
            @(negedge clk);
            wr_en = wr; rd_en = rd; din = data;
            @(posedge clk);
            #1;
            check(full,  (m_count == DEPTH), "full vs model");
            check(empty, (m_count == 0),     "empty vs model");
            check(dout,  m_dout,             "dout vs model");
        end
    endtask

    function [WIDTH-1:0] pat;
        input integer n;
        begin
            pat = n * 7 + 3;
        end
    endfunction

    integer i, phase, p_wr, p_rd, cnt;
    reg     w, r;

    initial begin
        rst = 1'b1; wr_en = 1'b0; rd_en = 1'b0; din = {WIDTH{1'b0}};
        m_count = 0; m_rp = 0; m_wp = 0; m_dout = {WIDTH{1'b0}};

        // ---- Reset ----
        cycle(1'b0, 1'b0, 8'h00);
        cycle(1'b1, 1'b1, 8'hFF);              // ignored during reset
        check(empty, 1, "empty after reset");
        check(full,  0, "not full after rst");
        check(dout,  0, "dout after reset");
        @(negedge clk);
        rst = 1'b0; wr_en = 1'b0; rd_en = 1'b0;   // idle before first real cycle

        // ---- 1. Write until full ----
        for (i = 0; i < DEPTH; i = i + 1) begin
            cycle(1'b1, 1'b0, pat(i));
            check(empty, 0, "not empty while fill");
            check(full, (i == DEPTH-1), "full only when full");
        end
        check(full, 1, "full is high");

        // ---- 2. Write while full: nothing changes ----
        for (i = 0; i < 3; i = i + 1) begin
            cycle(1'b1, 1'b0, 8'hEE);
            check(full, 1, "still full");
            check(m_count, DEPTH, "count unchanged");
        end

        // ---- 3. Read until empty, check order ----
        for (i = 0; i < DEPTH; i = i + 1) begin
            cycle(1'b0, 1'b1, 8'h00);
            check(dout, pat(i), "read order");
            check(full, 0, "not full after read");
            check(empty, (i == DEPTH-1), "empty only when empty");
        end
        check(empty, 1, "empty is high");

        // ---- 4. Read while empty: nothing changes ----
        for (i = 0; i < 3; i = i + 1) begin
            cycle(1'b0, 1'b1, 8'h00);
            check(empty, 1, "still empty");
            check(dout, pat(DEPTH-1), "dout holds");
        end
        // Read and write together while empty: write happens, read does not
        cycle(1'b1, 1'b1, 8'h5A);
        check(empty, 0, "wr+rd when empty");
        check(dout, pat(DEPTH-1), "dout not updated");
        cycle(1'b0, 1'b1, 8'h00);
        check(dout, 8'h5A, "read back 5A");
        check(empty, 1, "empty again");

        // ---- Read and write together while full: read happens, write does not ----
        for (i = 0; i < DEPTH; i = i + 1) cycle(1'b1, 1'b0, pat(i));
        check(full, 1, "full before wr+rd");
        cycle(1'b1, 1'b1, 8'hCC);
        check(full, 0, "wr+rd when full");
        check(dout, pat(0), "first value read");
        for (i = 1; i < DEPTH; i = i + 1) begin
            cycle(1'b0, 1'b1, 8'h00);
            check(dout, pat(i), "drain order");
        end
        check(empty, 1, "CC was not stored");   // 15 reads left, so CC was dropped

        // ---- Steady-state simultaneous read/write at half full ----
        for (i = 0; i < DEPTH/2; i = i + 1) cycle(1'b1, 1'b0, pat(i));
        for (i = 0; i < 40; i = i + 1) begin
            cycle(1'b1, 1'b1, pat(DEPTH/2 + i));
            check(dout, pat(i), "steady-state order");
            check(m_count, DEPTH/2, "level stays constant");
        end
        for (i = 0; i < DEPTH/2; i = i + 1) cycle(1'b0, 1'b1, 8'h00);
        check(empty, 1, "drained");

        // ---- 5. Random reads/writes, several traffic mixes ----
        for (phase = 0; phase < 6; phase = phase + 1) begin
            case (phase)
                0: begin p_wr = 128; p_rd = 128; end
                1: begin p_wr = 220; p_rd =  60; end   // mostly writes -> full
                2: begin p_wr =  60; p_rd = 220; end   // mostly reads  -> empty
                3: begin p_wr = 256; p_rd = 256; end   // both every cycle
                4: begin p_wr = 200; p_rd = 200; end
                default: begin p_wr = 100; p_rd = 160; end
            endcase
            for (cnt = 0; cnt < 500; cnt = cnt + 1) begin
                w = (($random & 255) < p_wr);
                r = (($random & 255) < p_rd);
                cycle(w, r, $random);
            end
        end

        // ---- Mid-operation reset ----
        for (i = 0; i < 5; i = i + 1) cycle(1'b1, 1'b0, $random);
        @(negedge clk);
        rst = 1'b1; wr_en = 1'b1; rd_en = 1'b0; din = 8'h77;
        @(posedge clk); #1;
        check(empty, 1, "empty after mid rst");
        check(full,  0, "not full after rst");
        check(dout,  0, "dout cleared");
        @(negedge clk);
        rst = 1'b0; wr_en = 1'b0; rd_en = 1'b0;
        cycle(1'b1, 1'b0, 8'h11);
        cycle(1'b0, 1'b1, 8'h00);
        check(dout, 8'h11, "works after reset");

        $display("Ran %0d checks", checks);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule