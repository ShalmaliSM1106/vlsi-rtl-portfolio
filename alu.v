// =============================================================================
// Module      : alu
// Description : Parameterized N-bit Arithmetic Logic Unit
//               Supports 8 operations: ADD, SUB, AND, OR, XOR, NOT, SHL, SHR
//               Output flags: Zero, Carry, Overflow, Negative
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

module alu #(
    parameter N = 4          // Bit width ? default 4, scalable to any width
)(
    input  wire [N-1:0]  A,        // Operand A
    input  wire [N-1:0]  B,        // Operand B
    input  wire [2:0]    opcode,   // Operation select (8 operations)

    output reg  [N-1:0]  result,   // ALU output
    output reg           zero,     // 1 if result == 0
    output reg           carry,    // 1 if unsigned overflow (ADD/SUB)
    output reg           overflow, // 1 if signed overflow (ADD/SUB)
    output reg           negative  // 1 if result is negative (MSB set)
);

// -----------------------------------------------------------------------------
// Opcode Definitions
// -----------------------------------------------------------------------------
localparam ADD = 3'b000;
localparam SUB = 3'b001;
localparam AND = 3'b010;
localparam OR  = 3'b011;
localparam XOR = 3'b100;
localparam NOT = 3'b101;
localparam SHL = 3'b110;   // Logical shift left by 1
localparam SHR = 3'b111;   // Logical shift right by 1

// -----------------------------------------------------------------------------
// Internal signals for carry/overflow detection
// -----------------------------------------------------------------------------
reg [N:0] temp;   // N+1 bits to capture carry out

// -----------------------------------------------------------------------------
// ALU Operation
// -----------------------------------------------------------------------------
always @(*) begin
    // Default all outputs
    result   = {N{1'b0}};
    carry    = 1'b0;
    overflow = 1'b0;
    temp     = {(N+1){1'b0}};

    case (opcode)

        ADD: begin
            temp     = {1'b0, A} + {1'b0, B};
            result   = temp[N-1:0];
            carry    = temp[N];                          // Unsigned carry out
            overflow = (A[N-1] == B[N-1]) &&            // Signed overflow:
                       (result[N-1] != A[N-1]);         // same sign in, diff sign out
        end

        SUB: begin
            temp     = {1'b0, A} - {1'b0, B};
            result   = temp[N-1:0];
            carry    = temp[N];                          // Borrow out for unsigned
            overflow = (A[N-1] != B[N-1]) &&            // Signed overflow:
                       (result[N-1] != A[N-1]);         // diff sign in, wrong sign out
        end

        AND: begin
            result = A & B;
        end

        OR: begin
            result = A | B;
        end

        XOR: begin
            result = A ^ B;
        end

        NOT: begin
            result = ~A;                                 // Bitwise NOT of A only
        end

        SHL: begin
            result = A << 1;                             // Logical shift left by 1
            carry  = A[N-1];                             // MSB shifted out
        end

        SHR: begin
            result = A >> 1;                             // Logical shift right by 1
            carry  = A[0];                               // LSB shifted out
        end

        default: begin
            result = {N{1'b0}};
        end

    endcase

    // Flags common to all operations
    zero     = (result == {N{1'b0}});
    negative = result[N-1];
end

endmodule