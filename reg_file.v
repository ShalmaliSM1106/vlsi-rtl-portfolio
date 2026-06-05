// =============================================================================
// Module      : reg_file
// Description : 8 x 16-bit Register File
//               2 read ports (combinational), 1 write port (synchronous)
//               Register 0 is hardwired to zero
// =============================================================================

module reg_file (
    input  wire        clk,
    input  wire        reg_write,       // Write enable
    input  wire [2:0]  read_reg1,       // Read port 1 address
    input  wire [2:0]  read_reg2,       // Read port 2 address
    input  wire [2:0]  write_reg,       // Write port address
    input  wire [15:0] write_data,      // Data to write

    output wire [15:0] read_data1,      // Read port 1 data
    output wire [15:0] read_data2       // Read port 2 data
);

reg [15:0] registers [0:7];

integer i;
initial begin
    for (i = 0; i < 8; i = i + 1)
        registers[i] = 16'h0000;
end

// Combinational reads ? register 0 always returns 0
assign read_data1 = (read_reg1 == 3'd0) ? 16'h0000 : registers[read_reg1];
assign read_data2 = (read_reg2 == 3'd0) ? 16'h0000 : registers[read_reg2];

// Synchronous write ? never write to register 0
always @(posedge clk) begin
    if (reg_write && write_reg != 3'd0)
        registers[write_reg] <= write_data;
end

endmodule