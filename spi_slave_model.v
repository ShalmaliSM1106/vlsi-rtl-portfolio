// =============================================================================
// Module      : spi_slave_model
// Description : Simple SPI Slave model for testbench use only
//               Receives data from master and sends back an echo response
//               Supports Mode 0 (CPOL=0, CPHA=0) for basic verification
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module spi_slave_model #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  sclk,
    input  wire                  cs_n,
    input  wire                  mosi,
    output reg                   miso,
    input  wire [DATA_WIDTH-1:0] slave_tx_data  // Data slave sends back
);

reg [DATA_WIDTH-1:0] rx_shift;
reg [DATA_WIDTH-1:0] tx_shift;
reg [3:0]            bit_count;

// Load TX shift register when CS goes low
always @(negedge cs_n) begin
    tx_shift  <= slave_tx_data;
    bit_count <= 0;
end

// Sample MOSI on rising SCLK, drive MISO on falling SCLK (Mode 0)
always @(posedge sclk) begin
    if (!cs_n) begin
        rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};
    end
end

always @(negedge sclk or negedge cs_n) begin
    if (!cs_n) begin
        miso <= tx_shift[DATA_WIDTH-1-bit_count];
        if (bit_count < DATA_WIDTH - 1)
            bit_count <= bit_count + 1;
    end else begin
        miso <= 1'bz;
    end
end

endmodule