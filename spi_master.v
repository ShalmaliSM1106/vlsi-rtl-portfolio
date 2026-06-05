// =============================================================================
// Module      : spi_master
// Description : SPI Master Controller
//               Supports all 4 SPI modes (CPOL/CPHA combinations)
//               Configurable clock divider
//               Transmits and receives 8 bits per transaction
//
//               SPI Modes:
//               Mode 0 (CPOL=0, CPHA=0): Clock idle low,  sample on rising  edge
//               Mode 1 (CPOL=0, CPHA=1): Clock idle low,  sample on falling edge
//               Mode 2 (CPOL=1, CPHA=0): Clock idle high, sample on falling edge
//               Mode 3 (CPOL=1, CPHA=1): Clock idle high, sample on rising  edge
//
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module spi_master #(
    parameter CLK_DIV   = 4,    // SPI clock = system clock / (2 * CLK_DIV)
    parameter DATA_WIDTH = 8    // Bits per transaction
)(
    input  wire                   clk,       // System clock
    input  wire                   reset,     // Synchronous reset, active high
    input  wire                   start,     // Pulse high to begin transaction
    input  wire [DATA_WIDTH-1:0]  tx_data,   // Data to send to slave
    input  wire                   cpol,      // Clock polarity
    input  wire                   cpha,      // Clock phase

    output reg  [DATA_WIDTH-1:0]  rx_data,   // Data received from slave
    output reg                    mosi,      // Master Out Slave In
    input  wire                   miso,      // Master In Slave Out
    output reg                    sclk,      // SPI clock to slave
    output reg                    cs_n,      // Chip select, active low
    output reg                    busy,      // High during transaction
    output reg                    done       // Pulses high 1 clock when done
);

// -----------------------------------------------------------------------------
// FSM States
// -----------------------------------------------------------------------------
localparam IDLE     = 2'd0;
localparam TRANSFER = 2'd1;
localparam FINISH   = 2'd2;

// -----------------------------------------------------------------------------
// Internal Registers
// -----------------------------------------------------------------------------
reg [1:0]              state;
reg [DATA_WIDTH-1:0]   tx_shift;       // Shift register for TX
reg [DATA_WIDTH-1:0]   rx_shift;       // Shift register for RX
reg [3:0]              bit_count;      // Counts bits transferred
reg [7:0]              clk_count;      // Clock divider counter
reg                    sclk_internal;  // Internal SPI clock before CPOL applied
reg                    sample_edge;    // 1 = sample on this edge
reg                    shift_edge;     // 1 = shift on this edge

// -----------------------------------------------------------------------------
// SPI Clock Generation and FSM
// -----------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        state         <= IDLE;
        sclk          <= 1'b0;
        sclk_internal <= 1'b0;
        cs_n          <= 1'b1;
        mosi          <= 1'b0;
        rx_data       <= {DATA_WIDTH{1'b0}};
        rx_shift      <= {DATA_WIDTH{1'b0}};
        tx_shift      <= {DATA_WIDTH{1'b0}};
        bit_count     <= 0;
        clk_count     <= 0;
        busy          <= 1'b0;
        done          <= 1'b0;
    end
    else begin
        done <= 1'b0; // Default ? pulse 1 clock only

        case (state)

            // ----------------------------------------------------------------
            IDLE: begin
                cs_n          <= 1'b1;
                busy          <= 1'b0;
                sclk_internal <= 1'b0;
                sclk          <= cpol; // Idle clock level set by CPOL
                bit_count     <= 0;
                clk_count     <= 0;

                if (start) begin
                    tx_shift  <= tx_data;
                    cs_n      <= 1'b0;  // Assert chip select
                    busy      <= 1'b1;
                    state     <= TRANSFER;

                    // For CPHA=1 shift first before sampling
                    // Pre-load MSB on MOSI before first clock edge
                    if (!cpha)
                        mosi <= tx_data[DATA_WIDTH-1];
                end
            end

            // ----------------------------------------------------------------
            TRANSFER: begin
                clk_count <= clk_count + 1;

                // Toggle SPI clock at CLK_DIV intervals
                if (clk_count == CLK_DIV - 1) begin
                    clk_count     <= 0;
                    sclk_internal <= ~sclk_internal;
                    sclk          <= sclk_internal ^ cpol; // Apply CPOL

                    // Determine sample/shift based on CPHA
                    // CPHA=0: sample on first edge (sclk_internal going high)
                    // CPHA=1: sample on second edge (sclk_internal going low)
                    if (cpha == 0) begin
                        if (sclk_internal == 0) begin
                            // Rising edge of internal clock ? sample MISO
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        end else begin
                            // Falling edge ? shift out next MOSI bit
                            if (bit_count < DATA_WIDTH - 1) begin
                                bit_count <= bit_count + 1;
                                mosi      <= tx_shift[DATA_WIDTH-2-bit_count];
                            end else begin
                                bit_count <= bit_count + 1;
                            end
                        end
                    end else begin
                        // CPHA=1
                        if (sclk_internal == 0) begin
                            // Rising edge ? shift out MOSI
                            if (bit_count < DATA_WIDTH) begin
                                mosi      <= tx_shift[DATA_WIDTH-1-bit_count];
                                bit_count <= bit_count + 1;
                            end
                        end else begin
                            // Falling edge ? sample MISO
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        end
                    end

                    // After 2*DATA_WIDTH edges (full byte), finish
                    if (bit_count == DATA_WIDTH) begin
                        state <= FINISH;
                    end
                end
            end

            // ----------------------------------------------------------------
            FINISH: begin
                cs_n    <= 1'b1;       // Deassert chip select
                sclk    <= cpol;       // Return clock to idle
                rx_data <= rx_shift;   // Latch received data
                busy    <= 1'b0;
                done    <= 1'b1;
                state   <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end
end

endmodule