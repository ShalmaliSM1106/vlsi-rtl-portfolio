// =============================================================================
// Module      : sync_fifo
// Description : Parameterized Synchronous FIFO with Status Flags
//               - Parameterized data width and depth
//               - Status flags: full, empty, almost_full, almost_empty
//               - Simultaneous read/write supported
//               - Overflow and underflow protected
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module sync_fifo #(
    parameter DATA_WIDTH  = 8,    // Width of each data word
    parameter FIFO_DEPTH  = 16,   // Number of entries (must be power of 2)
    parameter ALMOST_FULL_THRESHOLD  = 14, // almost_full when count >= this
    parameter ALMOST_EMPTY_THRESHOLD = 2   // almost_empty when count <= this
)(
    input  wire                  clk,
    input  wire                  reset,      // Synchronous reset, active high

    // Write port
    input  wire                  wr_en,      // Write enable
    input  wire [DATA_WIDTH-1:0] wr_data,    // Data to write

    // Read port
    input  wire                  rd_en,      // Read enable
    output reg  [DATA_WIDTH-1:0] rd_data,    // Data read out

    // Status flags
    output wire                  full,
    output wire                  empty,
    output wire                  almost_full,
    output wire                  almost_empty,
    output reg  [4:0]            count        // Number of entries currently in FIFO
);

// -----------------------------------------------------------------------------
// Local Parameters
// -----------------------------------------------------------------------------
localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

// -----------------------------------------------------------------------------
// Internal Memory and Pointers
// -----------------------------------------------------------------------------
reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
reg [ADDR_WIDTH-1:0] wr_ptr;   // Write pointer
reg [ADDR_WIDTH-1:0] rd_ptr;   // Read pointer

// -----------------------------------------------------------------------------
// Status Flags ? combinational
// -----------------------------------------------------------------------------
assign full         = (count == FIFO_DEPTH);
assign empty        = (count == 0);
assign almost_full  = (count >= ALMOST_FULL_THRESHOLD);
assign almost_empty = (count <= ALMOST_EMPTY_THRESHOLD);

// -----------------------------------------------------------------------------
// Write Logic
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        wr_ptr <= 0;
    end
    else if (wr_en && !full) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr      <= wr_ptr + 1;
    end
end

// -----------------------------------------------------------------------------
// Read Logic
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        rd_ptr  <= 0;
        rd_data <= {DATA_WIDTH{1'b0}};
    end
    else if (rd_en && !empty) begin
        rd_data <= mem[rd_ptr];
        rd_ptr  <= rd_ptr + 1;
    end
end

// -----------------------------------------------------------------------------
// Count Logic
// Handles simultaneous read+write, overflow protection, underflow protection
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        count <= 0;
    end
    else begin
        case ({wr_en, rd_en})
            2'b10: if (!full)              count <= count + 1; // Write only
            2'b01: if (!empty)             count <= count - 1; // Read only
            2'b11: begin                                        // Simultaneous
                if (full)        count <= count - 1; // Only read happens
                else if (empty)  count <= count + 1; // Only write happens
                // else count stays same ? one in one out
            end
            default: count <= count; // No operation
        endcase
    end
end

endmodule