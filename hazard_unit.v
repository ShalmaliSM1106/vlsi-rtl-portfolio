// =============================================================================
// Module      : hazard_unit
// Description : Hazard Detection Unit
//               Detects load-use data hazards and inserts stall (bubble)
//               Also handles branch and jump flushes
//
// Load-use hazard: instruction after LW needs the loaded value
// Solution: stall for 1 cycle (insert NOP bubble into EX stage)
// =============================================================================

module hazard_unit (
    // From ID/EX pipeline register
    input  wire        id_ex_mem_read,  // Was previous instruction a load?
    input  wire [2:0]  id_ex_rt,        // Destination of load

    // From IF/ID pipeline register
    input  wire [2:0]  if_id_rs,        // Source reg 1 of current instruction
    input  wire [2:0]  if_id_rt,        // Source reg 2 of current instruction

    // Branch/jump signals
    input  wire        branch_taken,
    input  wire        jump,

    // Outputs
    output reg         stall,           // Stall PC and IF/ID
    output reg         flush_ex,        // Flush ID/EX (insert bubble)
    output reg         flush_if         // Flush IF/ID on branch/jump
);

always @(*) begin
    stall    = 1'b0;
    flush_ex = 1'b0;
    flush_if = 1'b0;

    // Load-use hazard detection
    if (id_ex_mem_read &&
        ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt))) begin
        stall    = 1'b1;
        flush_ex = 1'b1;  // Insert bubble into EX stage
    end

    // Branch or jump taken ? flush the instruction in IF
    if (branch_taken || jump) begin
        flush_if = 1'b1;
    end
end

endmodule