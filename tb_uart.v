// =============================================================================
// Module      : tb_uart
// Description : Loopback testbench for UART TX + RX
//               TX output is directly connected to RX input
//               Tests multiple bytes and verifies received data matches sent
//               Self-checking with PASS/FAIL summary
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

`timescale 1ns/1ps

module tb_uart;

// -----------------------------------------------------------------------------
// Parameters
// Use small CLKS_PER_BIT for fast simulation (no need for real baud rates)
// -----------------------------------------------------------------------------
parameter CLKS_PER_BIT = 10;   // Small value so simulation runs fast
parameter CLK_PERIOD   = 10;   // 10ns clock

// -----------------------------------------------------------------------------
// DUT I/O
// -----------------------------------------------------------------------------
reg        clk;
reg        reset;
reg        tx_start;
reg  [7:0] tx_data;

wire       tx_line;   // Loopback wire: TX output ? RX input
wire       tx_busy;
wire       tx_done;
wire [7:0] rx_data;
wire       rx_done;
wire       rx_busy;

// -----------------------------------------------------------------------------
// Instantiate TX
// -----------------------------------------------------------------------------
uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
    .clk      (clk),
    .reset    (reset),
    .tx_start (tx_start),
    .tx_data  (tx_data),
    .tx       (tx_line),
    .tx_busy  (tx_busy),
    .tx_done  (tx_done)
);

// -----------------------------------------------------------------------------
// Instantiate RX ? loopback: tx_line feeds directly into rx
// -----------------------------------------------------------------------------
uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
    .clk      (clk),
    .reset    (reset),
    .rx       (tx_line),
    .rx_data  (rx_data),
    .rx_done  (rx_done),
    .rx_busy  (rx_busy)
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
// Task: send_and_check
// Sends one byte, waits for RX to complete, checks received data
// -----------------------------------------------------------------------------
task send_and_check;
    input [7:0] data;
    begin
        // Send byte
        @(posedge clk);
        tx_data  = data;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0;

        // Wait for RX done
        @(posedge rx_done);
        @(posedge clk); #1;

        // Check
        if (rx_data !== data) begin
            $display("FAIL | Sent: 0x%h (%b) | Received: 0x%h (%b)",
                data, data, rx_data, rx_data);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS | Sent: 0x%h (%b) | Received: 0x%h (%b)",
                data, data, rx_data, rx_data);
            pass_count = pass_count + 1;
        end
        total = total + 1;

        // Small gap between transmissions
        repeat(5) @(posedge clk);
    end
endtask

// -----------------------------------------------------------------------------
// Main Test Sequence
// -----------------------------------------------------------------------------
initial begin
    clk        = 0;
    reset      = 1;
    tx_start   = 0;
    tx_data    = 8'h00;
    pass_count = 0;
    fail_count = 0;
    total      = 0;

    // Reset for a few cycles
    repeat(5) @(posedge clk);
    reset = 0;
    repeat(2) @(posedge clk);

    $display("=============================================================");
    $display("  UART Loopback Testbench  |  CLKS_PER_BIT = %0d", CLKS_PER_BIT);
    $display("=============================================================");

    // --- Test various data patterns ---
    send_and_check(8'hA5);   // 10100101 ? alternating bits
    send_and_check(8'h00);   // All zeros
    send_and_check(8'hFF);   // All ones
    send_and_check(8'h55);   // 01010101
    send_and_check(8'hAA);   // 10101010
    send_and_check(8'h0F);   // Low nibble
    send_and_check(8'hF0);   // High nibble
    send_and_check(8'h01);   // LSB only
    send_and_check(8'h80);   // MSB only
    send_and_check(8'h3C);   // 00111100
    send_and_check(8'hC3);   // 11000011

    // --- ASCII characters ---
    send_and_check(8'h48);   // 'H'
    send_and_check(8'h69);   // 'i'
    send_and_check(8'h21);   // '!'

    // --- Summary ---
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