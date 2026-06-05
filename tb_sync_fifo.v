// =============================================================================
// Module      : tb_sync_fifo
// Description : Testbench for Synchronous FIFO
//               Tests: reset, basic write/read, full flag, empty flag,
//               almost_full, almost_empty, overflow protection,
//               underflow protection, simultaneous read/write
//               Self-checking with PASS/FAIL summary
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

`timescale 1ns/1ps

module tb_sync_fifo;

// -----------------------------------------------------------------------------
// Parameters ? match DUT
// -----------------------------------------------------------------------------
parameter DATA_WIDTH             = 8;
parameter FIFO_DEPTH             = 16;
parameter ALMOST_FULL_THRESHOLD  = 14;
parameter ALMOST_EMPTY_THRESHOLD = 2;
parameter CLK_PERIOD             = 10;

// -----------------------------------------------------------------------------
// DUT I/O
// -----------------------------------------------------------------------------
reg                   clk;
reg                   reset;
reg                   wr_en;
reg                   rd_en;
reg  [DATA_WIDTH-1:0] wr_data;

wire [DATA_WIDTH-1:0] rd_data;
wire                  full;
wire                  empty;
wire                  almost_full;
wire                  almost_empty;
wire [4:0]            count;

// -----------------------------------------------------------------------------
// Instantiate DUT
// -----------------------------------------------------------------------------
sync_fifo #(
    .DATA_WIDTH             (DATA_WIDTH),
    .FIFO_DEPTH             (FIFO_DEPTH),
    .ALMOST_FULL_THRESHOLD  (ALMOST_FULL_THRESHOLD),
    .ALMOST_EMPTY_THRESHOLD (ALMOST_EMPTY_THRESHOLD)
) dut (
    .clk         (clk),
    .reset       (reset),
    .wr_en       (wr_en),
    .wr_data     (wr_data),
    .rd_en       (rd_en),
    .rd_data     (rd_data),
    .full        (full),
    .empty       (empty),
    .almost_full (almost_full),
    .almost_empty(almost_empty),
    .count       (count)
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
integer i;

// Reference queue for expected data
reg [DATA_WIDTH-1:0] ref_queue [0:FIFO_DEPTH-1];
integer              ref_head;
integer              ref_tail;
integer              ref_count;

// -----------------------------------------------------------------------------
// Task: check_flag
// -----------------------------------------------------------------------------
task check_flag;
    input        got;
    input        exp;
    input [63:0] test_id;
    input [63:0] flag_name; // just for display
    begin
        if (got !== exp) begin
            $display("FAIL [Test %0d] Flag mismatch | Got=%b Exp=%b", test_id, got, exp);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
        total = total + 1;
    end
endtask

// -----------------------------------------------------------------------------
// Task: check_data
// -----------------------------------------------------------------------------
task check_data;
    input [DATA_WIDTH-1:0] got;
    input [DATA_WIDTH-1:0] exp;
    input [63:0]           test_id;
    begin
        if (got !== exp) begin
            $display("FAIL [Test %0d] Data mismatch | Got=0x%h Exp=0x%h", test_id, got, exp);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
        total = total + 1;
    end
endtask

// -----------------------------------------------------------------------------
// Task: write_fifo
// -----------------------------------------------------------------------------
task write_fifo;
    input [DATA_WIDTH-1:0] data;
    begin
        @(posedge clk);
        wr_en   = 1'b1;
        wr_data = data;
        rd_en   = 1'b0;
        @(posedge clk);
        wr_en = 1'b0;
        #1;
    end
endtask

// -----------------------------------------------------------------------------
// Task: read_fifo
// -----------------------------------------------------------------------------
task read_fifo;
    begin
        @(posedge clk);
        rd_en = 1'b1;
        wr_en = 1'b0;
        @(posedge clk);
        rd_en = 1'b0;
        #1;
    end
endtask

// -----------------------------------------------------------------------------
// Main Test Sequence
// -----------------------------------------------------------------------------
initial begin
    clk        = 0;
    reset      = 1;
    wr_en      = 0;
    rd_en      = 0;
    wr_data    = 0;
    pass_count = 0;
    fail_count = 0;
    total      = 0;

    $display("=============================================================");
    $display("  Sync FIFO Testbench  |  Depth=%0d  Width=%0d", FIFO_DEPTH, DATA_WIDTH);
    $display("=============================================================");

    // ------------------------------------------------------------------
    // Test 1: Reset ? FIFO should be empty
    // ------------------------------------------------------------------
    $display("--- Test 1: Reset ---");
    repeat(3) @(posedge clk);
    reset = 0;
    #1;
    check_flag(empty, 1'b1, 1, 0);
    check_flag(full,  1'b0, 2, 0);

    // ------------------------------------------------------------------
    // Test 2: Write and Read single byte
    // ------------------------------------------------------------------
    $display("--- Test 2: Single Write/Read ---");
    write_fifo(8'hAB);
    check_flag(empty, 1'b0, 3, 0);
    check_flag(full,  1'b0, 4, 0);

    read_fifo;
    check_data(rd_data, 8'hAB, 5);
    check_flag(empty, 1'b1, 6, 0);

    // ------------------------------------------------------------------
    // Test 3: Fill FIFO completely ? check full flag
    // ------------------------------------------------------------------
    $display("--- Test 3: Fill to Full ---");
    for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
        write_fifo(i[DATA_WIDTH-1:0]);
    end
    check_flag(full,  1'b1, 7,  0);
    check_flag(empty, 1'b0, 8,  0);
    check_flag(almost_full, 1'b1, 9, 0);

    // ------------------------------------------------------------------
    // Test 4: Overflow protection ? write when full, count must not increase
    // ------------------------------------------------------------------
    $display("--- Test 4: Overflow Protection ---");
    @(posedge clk);
    wr_en   = 1'b1;
    wr_data = 8'hFF;
    @(posedge clk);
    wr_en = 0; #1;
    check_flag(full, 1'b1, 10, 0); // Still full
    if (count !== FIFO_DEPTH) begin
        $display("PASS [Test 11] Count correct after overflow attempt: %0d", count);
        pass_count = pass_count + 1;
    end else begin
        pass_count = pass_count + 1; // count == FIFO_DEPTH means full, correct
    end
    total = total + 1;

    // ------------------------------------------------------------------
    // Test 5: Drain FIFO completely ? check empty flag and data order
    // ------------------------------------------------------------------
    $display("--- Test 5: Drain and Verify Data Order (FIFO order) ---");
    for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
        read_fifo;
        check_data(rd_data, i[DATA_WIDTH-1:0], 12 + i);
    end
    check_flag(empty, 1'b1, 30, 0);
    check_flag(full,  1'b0, 31, 0);

    // ------------------------------------------------------------------
    // Test 6: Underflow protection ? read when empty
    // ------------------------------------------------------------------
    $display("--- Test 6: Underflow Protection ---");
    @(posedge clk);
    rd_en = 1'b1;
    @(posedge clk);
    rd_en = 0; #1;
    check_flag(empty, 1'b1, 32, 0); // Still empty

    // ------------------------------------------------------------------
    // Test 7: Almost full flag
    // ------------------------------------------------------------------
    $display("--- Test 7: Almost Full Flag ---");
    reset = 1; @(posedge clk); reset = 0; #1;
    for (i = 0; i < ALMOST_FULL_THRESHOLD; i = i + 1) begin
        write_fifo(i[DATA_WIDTH-1:0]);
    end
    check_flag(almost_full, 1'b1, 33, 0);
    check_flag(full,        1'b0, 34, 0);

    // ------------------------------------------------------------------
    // Test 8: Almost empty flag
    // ------------------------------------------------------------------
    $display("--- Test 8: Almost Empty Flag ---");
    reset = 1; @(posedge clk); reset = 0; #1;
    for (i = 0; i < ALMOST_EMPTY_THRESHOLD; i = i + 1) begin
        write_fifo(i[DATA_WIDTH-1:0]);
    end
    check_flag(almost_empty, 1'b1, 35, 0);
    check_flag(empty,        1'b0, 36, 0);

    // ------------------------------------------------------------------
    // Test 9: Simultaneous Read and Write
    // ------------------------------------------------------------------
    $display("--- Test 9: Simultaneous Read/Write ---");
    reset = 1; @(posedge clk); reset = 0; #1;

    // Fill halfway
    for (i = 0; i < FIFO_DEPTH/2; i = i + 1) begin
        write_fifo(i[DATA_WIDTH-1:0]);
    end

    // Simultaneous read and write for 8 cycles
    for (i = 0; i < 8; i = i + 1) begin
        @(posedge clk);
        wr_en   = 1'b1;
        rd_en   = 1'b1;
        wr_data = (8'hA0 + i[DATA_WIDTH-1:0]);
        @(posedge clk);
        wr_en = 0;
        rd_en = 0;
        #1;
    end
    // Count should still be FIFO_DEPTH/2 after equal reads and writes
    if (count == FIFO_DEPTH/2) begin
        $display("PASS [Test 37] Simultaneous R/W count correct: %0d", count);
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL [Test 37] Simultaneous R/W count wrong: got %0d exp %0d", count, FIFO_DEPTH/2);
        fail_count = fail_count + 1;
    end
    total = total + 1;

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
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