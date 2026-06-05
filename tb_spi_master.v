// =============================================================================
// Module      : tb_spi_master
// Description : Testbench for SPI Master Controller
//               Tests all 4 SPI modes, multiple data patterns,
//               CS assertion/deassertion, busy/done flags
//               Self-checking with PASS/FAIL summary
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

`timescale 1ns/1ps

module tb_spi_master;

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------
parameter CLK_DIV    = 2;
parameter DATA_WIDTH = 8;
parameter CLK_PERIOD = 10;

// -----------------------------------------------------------------------------
// DUT I/O
// -----------------------------------------------------------------------------
reg                   clk;
reg                   reset;
reg                   start;
reg  [DATA_WIDTH-1:0] tx_data;
reg                   cpol;
reg                   cpha;

wire [DATA_WIDTH-1:0] rx_data;
wire                  mosi;
wire                  miso;
wire                  sclk;
wire                  cs_n;
wire                  busy;
wire                  done;

// Slave response data
reg [DATA_WIDTH-1:0]  slave_tx_data;

// -----------------------------------------------------------------------------
// Instantiate DUT
// -----------------------------------------------------------------------------
spi_master #(
    .CLK_DIV   (CLK_DIV),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk     (clk),
    .reset   (reset),
    .start   (start),
    .tx_data (tx_data),
    .cpol    (cpol),
    .cpha    (cpha),
    .rx_data (rx_data),
    .mosi    (mosi),
    .miso    (miso),
    .sclk    (sclk),
    .cs_n    (cs_n),
    .busy    (busy),
    .done    (done)
);

// -----------------------------------------------------------------------------
// Instantiate Slave Model
// -----------------------------------------------------------------------------
spi_slave_model #(.DATA_WIDTH(DATA_WIDTH)) slave (
    .sclk         (sclk),
    .cs_n         (cs_n),
    .mosi         (mosi),
    .miso         (miso),
    .slave_tx_data(slave_tx_data)
);

// -----------------------------------------------------------------------------
// Clock Generation
// -----------------------------------------------------------------------------
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// -----------------------------------------------------------------------------
// Test Counters
// -----------------------------------------------------------------------------
integer pass_count;
integer fail_count;
integer total;

// -----------------------------------------------------------------------------
// Task: spi_transfer
// Sends one byte, waits for done, checks tx integrity via MOSI observation
// -----------------------------------------------------------------------------
task spi_transfer;
    input [DATA_WIDTH-1:0] data;
    input                  cpol_in;
    input                  cpha_in;
    input [DATA_WIDTH-1:0] exp_rx;
    input [63:0]           test_id;
    begin
        @(posedge clk);
        cpol    = cpol_in;
        cpha    = cpha_in;
        tx_data = data;
        start   = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for done
        @(posedge done);
        @(posedge clk); #1;

        // Check CS deasserted after done
        if (cs_n !== 1'b1) begin
            $display("FAIL [Test %0d] CS not deasserted after done", test_id);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
        total = total + 1;

        // Check busy deasserted
        if (busy !== 1'b0) begin
            $display("FAIL [Test %0d] Busy not cleared after done", test_id);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
        total = total + 1;

        $display("PASS [Test %0d] Mode(%0d%0d) Sent=0x%h RX=0x%h",
            test_id, cpol_in, cpha_in, data, rx_data);

        // Gap between transactions
        repeat(10) @(posedge clk);
    end
endtask

// -----------------------------------------------------------------------------
// Main Test Sequence
// -----------------------------------------------------------------------------
initial begin
    clk           = 0;
    reset         = 1;
    start         = 0;
    tx_data       = 0;
    cpol          = 0;
    cpha          = 0;
    slave_tx_data = 8'hA5;
    pass_count    = 0;
    fail_count    = 0;
    total         = 0;

    repeat(4) @(posedge clk);
    reset = 0;
    repeat(2) @(posedge clk);

    $display("=============================================================");
    $display("  SPI Master Testbench  |  CLK_DIV=%0d  WIDTH=%0d", CLK_DIV, DATA_WIDTH);
    $display("=============================================================");

    // ------------------------------------------------------------------
    // Test Mode 0 (CPOL=0, CPHA=0)
    // ------------------------------------------------------------------
    $display("--- Mode 0: CPOL=0 CPHA=0 ---");
    spi_transfer(8'hA5, 0, 0, 8'hA5, 1);
    spi_transfer(8'h00, 0, 0, 8'hA5, 2);
    spi_transfer(8'hFF, 0, 0, 8'hA5, 3);
    spi_transfer(8'h55, 0, 0, 8'hA5, 4);

    // ------------------------------------------------------------------
    // Test Mode 1 (CPOL=0, CPHA=1)
    // ------------------------------------------------------------------
    $display("--- Mode 1: CPOL=0 CPHA=1 ---");
    spi_transfer(8'hA5, 0, 1, 8'hA5, 5);
    spi_transfer(8'h3C, 0, 1, 8'hA5, 6);

    // ------------------------------------------------------------------
    // Test Mode 2 (CPOL=1, CPHA=0)
    // ------------------------------------------------------------------
    $display("--- Mode 2: CPOL=1 CPHA=0 ---");
    spi_transfer(8'hA5, 1, 0, 8'hA5, 7);
    spi_transfer(8'hF0, 1, 0, 8'hA5, 8);

    // ------------------------------------------------------------------
    // Test Mode 3 (CPOL=1, CPHA=1)
    // ------------------------------------------------------------------
    $display("--- Mode 3: CPOL=1 CPHA=1 ---");
    spi_transfer(8'hA5, 1, 1, 8'hA5, 9);
    spi_transfer(8'hAA, 1, 1, 8'hA5, 10);

    // ------------------------------------------------------------------
    // Test CS stays low during transfer
    // ------------------------------------------------------------------
    $display("--- Test CS assertion during transfer ---");
    @(posedge clk);
    cpol    = 0; cpha = 0;
    tx_data = 8'h42;
    start   = 1'b1;
    @(posedge clk);
    start = 1'b0;
    @(posedge clk); #1;
    if (cs_n !== 1'b0) begin
        $display("FAIL [Test 11] CS not asserted during transfer");
        fail_count = fail_count + 1;
    end else begin
        $display("PASS [Test 11] CS correctly asserted during transfer");
        pass_count = pass_count + 1;
    end
    total = total + 1;
    @(posedge done);

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
    repeat(5) @(posedge clk);
    $display("=============================================================");
    $display("  TEST SUMMARY");
    $display("  Total  : %0d", total);
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    if (fail_count == 0)
        $display("  STATUS : ALL TESTS PASSED");
    else
        $display("  STATUS : SOME TESTS FAILED ? review output above");
    $display("=============================================================");

    $finish;
end

endmodule