// =============================================================================
// Module      : uart_tx
// Description : UART Transmitter
//               Format : 8N1 (8 data bits, No parity, 1 stop bit)
//               Configurable baud rate via CLKS_PER_BIT parameter
//               CLKS_PER_BIT = clock frequency / baud rate
//               Example: 50MHz clock, 115200 baud ? CLKS_PER_BIT = 434
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module uart_tx #(
    parameter CLKS_PER_BIT = 434   // Default: 50MHz / 115200 baud
)(
    input  wire       clk,         // System clock
    input  wire       reset,       // Synchronous reset, active high
    input  wire       tx_start,    // Pulse high for 1 clock to begin transmission
    input  wire [7:0] tx_data,     // Byte to transmit

    output reg        tx,          // Serial TX line (idle high)
    output reg        tx_busy,     // High while transmitting
    output reg        tx_done      // Pulses high for 1 clock when done
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
reg [2:0]  bit_index;       // Tracks which data bit we are sending (0?7)
reg [7:0]  tx_data_reg;     // Latched copy of tx_data
reg [15:0] clk_count;       // Baud rate counter

// -----------------------------------------------------------------------------
// UART TX FSM
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        state      <= IDLE;
        tx         <= 1'b1;   // Idle line is high
        tx_busy    <= 1'b0;
        tx_done    <= 1'b0;
        clk_count  <= 0;
        bit_index  <= 0;
        tx_data_reg<= 0;
    end
    else begin
        tx_done <= 1'b0; // Default ? pulse for 1 clock only

        case (state)

            IDLE: begin
                tx      <= 1'b1;
                tx_busy <= 1'b0;
                clk_count <= 0;
                bit_index <= 0;
                if (tx_start) begin
                    tx_data_reg <= tx_data;
                    tx_busy     <= 1'b1;
                    state       <= START_BIT;
                end
            end

            START_BIT: begin
                tx <= 1'b0;   // Start bit is low
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    state     <= DATA_BITS;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            DATA_BITS: begin
                tx <= tx_data_reg[bit_index];  // LSB first
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
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

            STOP_BIT: begin
                tx <= 1'b1;   // Stop bit is high
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    state     <= DONE;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            DONE: begin
                tx_done <= 1'b1;
                tx_busy <= 1'b0;
                state   <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end
end

endmodule