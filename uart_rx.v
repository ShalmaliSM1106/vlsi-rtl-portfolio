// =============================================================================
// Module      : uart_rx
// Description : UART Receiver
//               Format : 8N1 (8 data bits, No parity, 1 stop bit)
//               Samples at the middle of each bit period for reliability
//               CLKS_PER_BIT must match uart_tx
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module uart_rx #(
    parameter CLKS_PER_BIT = 434
)(
    input  wire       clk,         // System clock
    input  wire       reset,       // Synchronous reset, active high
    input  wire       rx,          // Serial RX line

    output reg  [7:0] rx_data,     // Received byte
    output reg        rx_done,     // Pulses high for 1 clock when byte received
    output reg        rx_busy      // High while receiving
);

// -----------------------------------------------------------------------------
// FSM States
// -----------------------------------------------------------------------------
localparam IDLE       = 3'd0;
localparam START_BIT  = 3'd1;
localparam DATA_BITS  = 3'd2;
localparam STOP_BIT   = 3'd3;
localparam DONE       = 3'd4;

// -----------------------------------------------------------------------------
// Internal Registers
// -----------------------------------------------------------------------------
reg [2:0]  state;
reg [2:0]  bit_index;
reg [15:0] clk_count;
reg [7:0]  rx_data_reg;

// -----------------------------------------------------------------------------
// UART RX FSM
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        state      <= IDLE;
        rx_data    <= 8'h00;
        rx_done    <= 1'b0;
        rx_busy    <= 1'b0;
        clk_count  <= 0;
        bit_index  <= 0;
        rx_data_reg<= 0;
    end
    else begin
        rx_done <= 1'b0; // Default ? pulse for 1 clock only

        case (state)

            IDLE: begin
                rx_busy   <= 1'b0;
                clk_count <= 0;
                bit_index <= 0;
                if (rx == 1'b0) begin   // Detect start bit (line goes low)
                    rx_busy <= 1'b1;
                    state   <= START_BIT;
                end
            end

            // Wait to the MIDDLE of the start bit to confirm it's valid
            START_BIT: begin
                if (clk_count == (CLKS_PER_BIT/2) - 1) begin
                    if (rx == 1'b0) begin   // Still low ? valid start bit
                        clk_count <= 0;
                        state     <= DATA_BITS;
                    end else begin          // Glitch ? go back to idle
                        state <= IDLE;
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            // Sample each data bit at its midpoint
            DATA_BITS: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count              <= 0;
                    rx_data_reg[bit_index] <= rx;   // Sample LSB first
                    if (bit_index == 7) begin
                        bit_index <= 0;
                        state     <= STOP_BIT;
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            // Wait through stop bit
            STOP_BIT: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    state     <= DONE;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            DONE: begin
                rx_data <= rx_data_reg;
                rx_done <= 1'b1;
                rx_busy <= 1'b0;
                state   <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end
end

endmodule