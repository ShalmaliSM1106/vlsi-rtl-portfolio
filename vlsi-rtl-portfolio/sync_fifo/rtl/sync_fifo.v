`timescale 1ns/1ps
// Synchronous FIFO, single clock. DEPTH must be a power of 2.
// dout is registered: data appears on dout one clock after the cycle in which
// rd_en was accepted, and holds its value otherwise.
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input              clk,
    input              rst,       // synchronous, active-high
    input              wr_en,
    input  [WIDTH-1:0] din,
    input              rd_en,
    output reg [WIDTH-1:0] dout,
    output             full,
    output             empty
);

    // Verilog-2001 has no $clog2, so use a constant function
    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam AW = clog2(DEPTH);          // 4 for DEPTH = 16

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0]      wr_ptr;                // one extra bit to detect wrap-around
    reg [AW:0]      rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[AW] != rd_ptr[AW]) &&
                   (wr_ptr[AW-1:0] == rd_ptr[AW-1:0]);

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {(AW+1){1'b0}};
            rd_ptr <= {(AW+1){1'b0}};
            dout   <= {WIDTH{1'b0}};
        end else begin
            if (do_wr) begin
                mem[wr_ptr[AW-1:0]] <= din;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (do_rd) begin
                dout   <= mem[rd_ptr[AW-1:0]];
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

endmodule
