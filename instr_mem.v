// =============================================================================
// Module      : instr_mem
// Description : Instruction Memory ? 256 x 16-bit ROM
//               Initialized with a test program
//               Read-only, combinational output
// =============================================================================

module instr_mem (
    input  wire [15:0] addr,
    output wire [15:0] instr
);

reg [15:0] mem [0:255];

// Load program at initialization
initial $readmemh("program.hex", mem);

assign instr = mem[addr[7:0]]; // Word-addressed, lower 8 bits

endmodule