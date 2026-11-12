`timescale 1ns/1ps
module tb_spi_master;

    parameter CLK_DIV = 4;

    reg        clk = 0;
    reg        rst = 1;
    reg        start = 0;
    reg  [7:0] tx_byte = 8'h00;
    wire       miso;
    wire       sclk, mosi, cs_n, busy, done;
    wire [7:0] rx_byte;

    spi_master #(.CLK_DIV(CLK_DIV)) dut (
        .clk(clk), .rst(rst), .start(start), .tx_byte(tx_byte), .miso(miso),
        .sclk(sclk), .mosi(mosi), .cs_n(cs_n), .rx_byte(rx_byte),
        .busy(busy), .done(done)
    );

    always #5 clk = ~clk;   // 100 MHz

    // ---------------- self-checking infrastructure ----------------
    integer errors = 0;
    task check(input [31:0] got, input [31:0] exp, input [8*20:1] msg);
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL %s: got %h, expected %h", msg, got, exp);
        end
    endtask

    // ---------------- SPI slave model (mode 0) ----------------
    reg [7:0] slave_data = 8'h00;   // byte the slave will send back
    reg [7:0] slave_tx   = 8'h00;
    reg [7:0] slave_rx   = 8'h00;   // byte the slave captured from MOSI

    assign miso = cs_n ? 1'bz : slave_tx[7];

    always @(negedge cs_n) begin
        slave_tx = slave_data;      // load at start of transfer
        slave_rx = 8'h00;
    end
    always @(posedge sclk) if (!cs_n) slave_rx = {slave_rx[6:0], mosi};  // sample on rising
    always @(negedge sclk) if (!cs_n) slave_tx = {slave_tx[6:0], 1'b0};  // shift on falling

    // ---------------- one transfer ----------------
    integer timeout;
    integer rise_cnt;
    always @(posedge sclk) rise_cnt = rise_cnt + 1;

    task do_transfer(input [7:0] m_byte, input [7:0] s_byte);
        begin
            slave_data = s_byte;
            rise_cnt   = 0;
            @(negedge clk);
            tx_byte = m_byte;
            start   = 1'b1;
            @(negedge clk);
            start   = 1'b0;
            check(busy, 1, "busy during xfer");
            check(cs_n, 0, "cs_n low");
            timeout = 0;
            while (!done && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            check(timeout < 1000, 1, "no timeout");
            check(rx_byte,  s_byte, "master rx_byte");
            check(slave_rx, m_byte, "slave rx (mosi)");
            check(rise_cnt, 8,      "8 sclk rising edges");
            @(negedge clk);
            check(done, 0, "done is 1 pulse");
            check(busy, 0, "busy low after");
            check(cs_n, 1, "cs_n high after");
            check(sclk, 0, "sclk idle low");
            repeat (3) @(negedge clk);
        end
    endtask

    integer i;

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        check(cs_n, 1, "cs_n idle");
        check(sclk, 0, "sclk idle");
        check(busy, 0, "busy idle");

        do_transfer(8'hA5, 8'h3C);
        do_transfer(8'h00, 8'hFF);
        do_transfer(8'hFF, 8'h00);
        do_transfer(8'h81, 8'h7E);
        do_transfer(8'h55, 8'hAA);
        do_transfer(8'h12, 8'h34);

        // 100 random byte pairs
        for (i = 0; i < 100; i = i + 1)
            do_transfer($random, $random);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule
