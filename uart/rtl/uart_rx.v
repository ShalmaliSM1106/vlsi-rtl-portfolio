`timescale 1ns/1ps
// UART receiver: 2-FF synchronizer, start-bit detect, mid-bit sampling, LSB first
module uart_rx #(
    parameter CLKS_PER_BIT = 16      // must be >= 4
)(
    input            clk,
    input            rst,            // synchronous, active-high
    input            rx,             // asynchronous serial input
    output reg [7:0] rx_data,
    output reg       rx_valid        // one-clock pulse when a byte has been received
);

    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;
    localparam S_ERR   = 3'd4;       // bad stop bit: wait for line to return high

    localparam HALF = CLKS_PER_BIT/2 - 1;

    // Two flip-flops in series: rx comes from outside and is not synchronous to clk.
    // The first FF may go metastable; giving it a full clock period to settle
    // before the second FF (which feeds the logic) makes a failure very unlikely.
    reg rx_s1, rx_s2;

    reg [2:0]  state;
    reg [31:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shreg;

    always @(posedge clk) begin
        if (rst) begin
            rx_s1 <= 1'b1;
            rx_s2 <= 1'b1;
        end else begin
            rx_s1 <= rx;
            rx_s2 <= rx_s1;
        end
    end

    always @(posedge clk) begin
        rx_valid <= 1'b0;                              // default: pulse lasts one clock
        if (rst) begin
            state   <= S_IDLE;
            clk_cnt <= 32'd0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
            rx_data <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    clk_cnt <= 32'd0;
                    bit_idx <= 3'd0;
                    if (!rx_s2) state <= S_START;      // falling line = possible start bit
                end

                S_START: begin                          // go to the middle of the start bit
                    if (clk_cnt == HALF) begin
                        clk_cnt <= 32'd0;
                        if (!rx_s2) state <= S_DATA;   // still low: real start bit
                        else        state <= S_IDLE;   // glitch: ignore
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                S_DATA: begin                           // one sample per bit, at its middle
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 32'd0;
                        shreg   <= {rx_s2, shreg[7:1]}; // LSB arrives first, ends up at bit 0
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 32'd0;
                        if (rx_s2) begin                // valid stop bit
                            rx_data  <= shreg;
                            rx_valid <= 1'b1;
                            state    <= S_IDLE;
                        end else
                            state <= S_ERR;             // framing error: drop byte
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                S_ERR: begin
                    if (rx_s2) state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
