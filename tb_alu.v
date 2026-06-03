// =============================================================================
// Module      : tb_alu
// Description : Exhaustive testbench for parameterized ALU
//               Loops through all input combinations for each opcode
//               Checks results against golden reference model
//               Reports PASS/FAIL per test and final summary
// Author      : Shalmali Mankikar
// Tools       : ModelSim
// =============================================================================

`timescale 1ns/1ps

module tb_alu;

// -----------------------------------------------------------------------------
// Parameters ? change N here to test different widths
// -----------------------------------------------------------------------------
parameter N = 4;

// -----------------------------------------------------------------------------
// DUT I/O ? all regs so we can drive them directly
// -----------------------------------------------------------------------------
reg  [N-1:0]  A;
reg  [N-1:0]  B;
reg  [2:0]    opcode;

wire [N-1:0]  result;
wire          zero;
wire          carry;
wire          overflow;
wire          negative;

// -----------------------------------------------------------------------------
// Instantiate DUT
// -----------------------------------------------------------------------------
alu #(.N(N)) dut (
    .A        (A),
    .B        (B),
    .opcode   (opcode),
    .result   (result),
    .zero     (zero),
    .carry    (carry),
    .overflow (overflow),
    .negative (negative)
);

// -----------------------------------------------------------------------------
// Golden Reference Registers
// -----------------------------------------------------------------------------
reg [N:0]   temp_ref;
reg [N-1:0] exp_result;
reg         exp_zero, exp_carry, exp_overflow, exp_negative;

// -----------------------------------------------------------------------------
// Test Counters
// -----------------------------------------------------------------------------
integer pass_count;
integer fail_count;
integer total;

// Loop variables ? use integers, cast when assigning to reg
integer i, j, op;

// -----------------------------------------------------------------------------
// Helper regs to hold loop values as bit vectors
// -----------------------------------------------------------------------------
reg [N-1:0]  a_vec;
reg [N-1:0]  b_vec;
reg [2:0]    op_vec;

// -----------------------------------------------------------------------------
// Main Test Logic
// -----------------------------------------------------------------------------
initial begin
    // Initialise inputs to known state
    A      = {N{1'b0}};
    B      = {N{1'b0}};
    opcode = 3'b000;

    pass_count = 0;
    fail_count = 0;
    total      = 0;

    #5; // Small startup delay

    $display("=============================================================");
    $display("  ALU Exhaustive Testbench  |  N = %0d bits", N);
    $display("=============================================================");

    for (op = 0; op <= 7; op = op + 1) begin

        op_vec = op[2:0];
        $display("--- Testing opcode %03b ---", op_vec);

        for (i = 0; i <= ((1<<N)-1); i = i + 1) begin
            for (j = 0; j <= ((1<<N)-1); j = j + 1) begin

                // Cast integers to bit vectors explicitly
                a_vec  = i[N-1:0];
                b_vec  = j[N-1:0];

                // Drive DUT inputs
                A      = a_vec;
                B      = b_vec;
                opcode = op_vec;

                #5; // Wait for combinational outputs to settle

                // ----------------------------------------------------------
                // Golden Reference Model
                // ----------------------------------------------------------
                exp_carry    = 1'b0;
                exp_overflow = 1'b0;
                temp_ref     = {(N+1){1'b0}};

                case (op_vec)
                    3'b000: begin // ADD
                        temp_ref     = ({1'b0, a_vec} + {1'b0, b_vec});
                        exp_result   = temp_ref[N-1:0];
                        exp_carry    = temp_ref[N];
                        exp_overflow = (a_vec[N-1] == b_vec[N-1]) &&
                                       (exp_result[N-1] != a_vec[N-1]);
                    end
                    3'b001: begin // SUB
                        temp_ref     = ({1'b0, a_vec} - {1'b0, b_vec});
                        exp_result   = temp_ref[N-1:0];
                        exp_carry    = temp_ref[N];
                        exp_overflow = (a_vec[N-1] != b_vec[N-1]) &&
                                       (exp_result[N-1] != a_vec[N-1]);
                    end
                    3'b010: begin // AND
                        exp_result = a_vec & b_vec;
                    end
                    3'b011: begin // OR
                        exp_result = a_vec | b_vec;
                    end
                    3'b100: begin // XOR
                        exp_result = a_vec ^ b_vec;
                    end
                    3'b101: begin // NOT
                        exp_result = ~a_vec;
                    end
                    3'b110: begin // SHL
                        exp_result = {a_vec[N-2:0], 1'b0};
                        exp_carry  = a_vec[N-1];
                    end
                    3'b111: begin // SHR
                        exp_result = {1'b0, a_vec[N-1:1]};
                        exp_carry  = a_vec[0];
                    end
                    default: exp_result = {N{1'b0}};
                endcase

                exp_zero     = (exp_result == {N{1'b0}});
                exp_negative = exp_result[N-1];

                // ----------------------------------------------------------
                // Compare DUT vs Reference
                // ----------------------------------------------------------
                if (result   !== exp_result  ||
                    zero     !== exp_zero     ||
                    carry    !== exp_carry    ||
                    overflow !== exp_overflow ||
                    negative !== exp_negative) begin

                    $display("FAIL | op=%03b A=%b B=%b | Got: result=%b z=%b c=%b ov=%b neg=%b | Exp: result=%b z=%b c=%b ov=%b neg=%b",
                        op_vec, a_vec, b_vec,
                        result, zero, carry, overflow, negative,
                        exp_result, exp_zero, exp_carry, exp_overflow, exp_negative);
                    fail_count = fail_count + 1;
                end else begin
                    pass_count = pass_count + 1;
                end

                total = total + 1;

            end // j loop
        end // i loop
    end // op loop

    // ----------------------------------------------------------
    // Summary
    // ----------------------------------------------------------
    $display("=============================================================");
    $display("  TEST SUMMARY");
    $display("  Total  : %0d", total);
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    if (fail_count == 0)
        $display("  STATUS : ALL TESTS PASSED");
    else
        $display("  STATUS : SOME TESTS FAILED ? review output above");
    $display("=============================================================");

    $finish;
end

endmodule