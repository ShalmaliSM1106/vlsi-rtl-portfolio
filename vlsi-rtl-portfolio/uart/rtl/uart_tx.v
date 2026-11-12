`timescale 1ns/1ps
// UART transmitter: idle high, start bit (0), 8 data bits LSB first, stop bit (1)
module uart_tx #(
    parameter CLKS_PER_BIT = 16      // clock frequency / baud rate (e.g. 50e6/9600 = 5208)
)(
    input            clk,
    input            rst,            // synchronous, active-high
    input            tx_start,       // pulse for one clock to send tx_data (ignored while busy)
    input      [7:0] tx_data,
    output reg       tx,
    output reg       tx_busy
);

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [31:0] clk_cnt;              // counts clocks within one bit
    reg [2:0]  bit_idx;              // 0..7
    reg [7:0]  shreg;                // copy of tx_data, so the input may change after start

    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            clk_cnt <= 32'd0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
            tx      <= 1'b1;
            tx_busy <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 32'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        shreg   <= tx_data;
                        tx      <= 1'b0;               // start bit begins now
                        tx_busy <= 1'b1;
                        state   <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 32'd0;
                        bit_idx <= 3'd0;
                        tx      <= shreg[0];           // LSB first
                        state   <= S_DATA;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 32'd0;
                        if (bit_idx == 3'd7) begin
                            tx    <= 1'b1;             // stop bit
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                            tx      <= shreg[bit_idx + 1'b1];
                        end
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                S_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 32'd0;
                        tx_busy <= 1'b0;
                        state   <= S_IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
