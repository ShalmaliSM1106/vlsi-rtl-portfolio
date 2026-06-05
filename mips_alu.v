// =============================================================================
// Module      : mips_alu
// Description : 16-bit ALU for MIPS CPU
//               Operations: ADD, SUB, AND, OR, SLT (set less than)
// =============================================================================

module mips_alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [2:0]  alu_ctrl,

    output reg  [15:0] result,
    output wire        zero        // High when result == 0
);

// ALU Control codes
localparam ALU_AND = 3'b000;
localparam ALU_OR  = 3'b001;
localparam ALU_ADD = 3'b010;
localparam ALU_SUB = 3'b110;
localparam ALU_SLT = 3'b111;

assign zero = (result == 16'h0000);

always @(*) begin
    case (alu_ctrl)
        ALU_AND: result = a & b;
        ALU_OR:  result = a | b;
        ALU_ADD: result = a + b;
        ALU_SUB: result = a - b;
        ALU_SLT: result = ($signed(a) < $signed(b)) ? 16'h0001 : 16'h0000;
        default: result = 16'h0000;
    endcase
end

endmodule