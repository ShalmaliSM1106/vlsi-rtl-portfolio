`timescale 1ns/1ps
// SPI master, mode 0 (CPOL=0, CPHA=0), MSB first, 8-bit transfers.
// sclk idles low; MISO is sampled on the rising edge, MOSI changes on the falling edge.
// Synchronous, active-high reset.
module spi_master #(
    parameter CLK_DIV = 4          // system clocks per half sclk period
)(
    input            clk,
    input            rst,
    input            start,        // pulse high for one clock in IDLE to begin
    input      [7:0] tx_byte,
    input            miso,
    output reg       sclk,
    output reg       mosi,
    output reg       cs_n,
    output reg [7:0] rx_byte,
    output reg       busy,
    output reg       done          // one-clock pulse when transfer completes
);

    localparam IDLE     = 2'd0;
    localparam TRANSFER = 2'd1;
    localparam DONE     = 2'd2;

    reg [1:0] state;
    reg [15:0] clk_cnt;            // counts system clocks within a half sclk period
    reg [4:0]  toggle_cnt;         // 0..15 (16 sclk toggles = 8 bits)
    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            clk_cnt    <= 0;
            toggle_cnt <= 0;
            tx_shift   <= 8'h00;
            rx_shift   <= 8'h00;
            sclk       <= 1'b0;
            mosi       <= 1'b0;
            cs_n       <= 1'b1;
            rx_byte    <= 8'h00;
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;                          // default: done is a one-clock pulse
            case (state)
                IDLE: begin
                    sclk <= 1'b0;
                    cs_n <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        cs_n       <= 1'b0;        // select slave
                        tx_shift   <= tx_byte;     // load shift register
                        mosi       <= tx_byte[7];  // MSB valid before first rising edge
                        rx_shift   <= 8'h00;
                        clk_cnt    <= 0;
                        toggle_cnt <= 0;
                        busy       <= 1'b1;
                        state      <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt    <= 0;
                        sclk       <= ~sclk;
                        toggle_cnt <= toggle_cnt + 1'b1;
                        if (sclk == 1'b0) begin
                            // rising edge: sample MISO
                            rx_shift <= {rx_shift[6:0], miso};
                        end else begin
                            // falling edge: shift out next MOSI bit
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi     <= tx_shift[6];
                            if (toggle_cnt == 5'd15)   // 16th toggle: last falling edge
                                state <= DONE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DONE: begin
                    cs_n    <= 1'b1;
                    rx_byte <= rx_shift;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
