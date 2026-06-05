// =============================================================================
// Module      : program_counter
// Description : 16-bit Program Counter
//               Supports normal increment, branch, and jump
// =============================================================================

module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] pc_next,   // Next PC value from control logic
    output reg  [15:0] pc         // Current PC
);

always @(posedge clk) begin
    if (reset)
        pc <= 16'h0000;
    else
        pc <= pc_next;
end

endmodule