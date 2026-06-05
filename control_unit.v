// =============================================================================
// Module      : control_unit
// Description : Main Control Unit ? decodes opcode and generates control signals
//
// Instruction Format (16-bit):
//   R-type: [15:13]=000  [12:10]=rs  [9:7]=rt  [6:4]=rd  [3:1]=shamt [0]=funct
//   I-type: [15:13]=opc  [12:10]=rs  [9:7]=rt  [6:0]=imm7
//   J-type: [15:13]=111  [12:0]=addr13
//
// Opcodes:
//   000 = R-type (ADD, SUB, AND, OR determined by funct)
//   001 = LW
//   010 = SW
//   011 = BEQ
//   100 = ADDI
//   111 = J
// =============================================================================

module control_unit (
    input  wire [2:0]  opcode,

    output reg         reg_dst,      // 1=rd is dest, 0=rt is dest
    output reg         alu_src,      // 1=immediate, 0=register
    output reg         mem_to_reg,   // 1=load from mem, 0=ALU result
    output reg         reg_write,    // Enable register write
    output reg         mem_read,     // Enable memory read
    output reg         mem_write,    // Enable memory write
    output reg         branch,       // BEQ instruction
    output reg         jump,         // J instruction
    output reg [1:0]   alu_op        // Passed to ALU control
);

always @(*) begin
    // Defaults
    reg_dst   = 0;
    alu_src   = 0;
    mem_to_reg= 0;
    reg_write = 0;
    mem_read  = 0;
    mem_write = 0;
    branch    = 0;
    jump      = 0;
    alu_op    = 2'b00;

    case (opcode)
        3'b000: begin // R-type
            reg_dst   = 1;
            reg_write = 1;
            alu_op    = 2'b10;
        end
        3'b001: begin // LW
            alu_src   = 1;
            mem_to_reg= 1;
            reg_write = 1;
            mem_read  = 1;
            alu_op    = 2'b00; // ADD for address calc
        end
        3'b010: begin // SW
            alu_src   = 1;
            mem_write = 1;
            alu_op    = 2'b00;
        end
        3'b011: begin // BEQ
            branch    = 1;
            alu_op    = 2'b01; // SUB for comparison
        end
        3'b100: begin // ADDI
            alu_src   = 1;
            reg_write = 1;
            alu_op    = 2'b00;
        end
        3'b111: begin // J
            jump      = 1;
        end
        default: begin
            // NOP ? all zeros
        end
    endcase
end

endmodule