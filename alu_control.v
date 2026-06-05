// =============================================================================
// Module      : alu_control
// Description : ALU Control Unit
//               Determines exact ALU operation from alu_op + funct field
//
// alu_op:
//   00 = ADD (for LW, SW, ADDI)
//   01 = SUB (for BEQ)
//   10 = R-type (use funct field)
//
// funct field (R-type):
//   000 = ADD
//   001 = SUB
//   010 = AND
//   011 = OR
//   100 = SLT
// =============================================================================

module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct,
    output reg  [2:0] alu_ctrl
);

always @(*) begin
    case (alu_op)
        2'b00: alu_ctrl = 3'b010; // ADD
        2'b01: alu_ctrl = 3'b110; // SUB
        2'b10: begin
            case (funct)
                3'b000: alu_ctrl = 3'b010; // ADD
                3'b001: alu_ctrl = 3'b110; // SUB
                3'b010: alu_ctrl = 3'b000; // AND
                3'b011: alu_ctrl = 3'b001; // OR
                3'b100: alu_ctrl = 3'b111; // SLT
                default:alu_ctrl = 3'b010;
            endcase
        end
        default: alu_ctrl = 3'b010;
    endcase
end

endmodule