// =============================================================================
// Module      : mips_cpu
// Description : 16-bit Pipelined MIPS CPU ? 4 Stage
//               Stages: IF (Fetch) ? ID (Decode) ? EX (Execute) ? WB (Writeback)
//
// Supported Instructions:
//   ADD, SUB, AND, OR, SLT, ADDI, LW, SW, BEQ, J
// =============================================================================

module mips_cpu (
    input  wire clk,
    input  wire reset
);

// =============================================================================
// STAGE 1 ? IF: Instruction Fetch
// =============================================================================
wire [15:0] pc_current;
wire [15:0] pc_plus1 = pc_current + 1;
wire [15:0] instr_if;

// Forward declarations for hazard/branch signals
wire        stall;
wire        flush_if;
wire        branch_taken;
wire        jump_taken;
wire [15:0] branch_target;
wire [15:0] jump_target;

wire [15:0] pc_next =
    (stall)        ? pc_current    :
    (jump_taken)   ? jump_target   :
    (branch_taken) ? branch_target :
                     pc_plus1;

program_counter u_pc (
    .clk    (clk),
    .reset  (reset),
    .pc_next(pc_next),
    .pc     (pc_current)
);

instr_mem u_imem (
    .addr (pc_current),
    .instr(instr_if)
);

// IF/ID Pipeline Register
reg [15:0] if_id_pc;
reg [15:0] if_id_instr;

always @(posedge clk) begin
    if (reset || flush_if) begin
        if_id_pc    <= 0;
        if_id_instr <= 0;
    end
    else if (!stall) begin
        if_id_pc    <= pc_plus1;
        if_id_instr <= instr_if;
    end
end

// =============================================================================
// STAGE 2 ? ID: Decode + Register Read
// =============================================================================
wire [2:0]  id_opcode = if_id_instr[15:13];
wire [2:0]  id_rs     = if_id_instr[12:10];
wire [2:0]  id_rt     = if_id_instr[9:7];
wire [2:0]  id_rd     = if_id_instr[6:4];
wire [2:0]  id_funct  = if_id_instr[2:0];
wire [6:0]  id_imm7   = if_id_instr[6:0];
wire [15:0] id_imm_se = {{9{id_imm7[6]}}, id_imm7};
wire [12:0] id_jaddr  = if_id_instr[12:0];

// Control signals
wire        ctrl_reg_dst, ctrl_alu_src, ctrl_mem_to_reg;
wire        ctrl_reg_write, ctrl_mem_read, ctrl_mem_write;
wire        ctrl_branch, ctrl_jump;
wire [1:0]  ctrl_alu_op;

control_unit u_ctrl (
    .opcode    (id_opcode),
    .reg_dst   (ctrl_reg_dst),
    .alu_src   (ctrl_alu_src),
    .mem_to_reg(ctrl_mem_to_reg),
    .reg_write (ctrl_reg_write),
    .mem_read  (ctrl_mem_read),
    .mem_write (ctrl_mem_write),
    .branch    (ctrl_branch),
    .jump      (ctrl_jump),
    .alu_op    (ctrl_alu_op)
);

// Register file wires (WB stage drives write port)
wire        wb_reg_write;
wire [2:0]  wb_write_reg;
wire [15:0] wb_write_data;
wire [15:0] rf_rd1, rf_rd2;

reg_file u_rf (
    .clk       (clk),
    .reg_write (wb_reg_write),
    .read_reg1 (id_rs),
    .read_reg2 (id_rt),
    .write_reg (wb_write_reg),
    .write_data(wb_write_data),
    .read_data1(rf_rd1),
    .read_data2(rf_rd2)
);

// Branch and jump resolution in ID
assign branch_target = if_id_pc + id_imm_se;
assign branch_taken  = ctrl_branch && (rf_rd1 == rf_rd2);
assign jump_target   = {3'b000, id_jaddr};
assign jump_taken    = ctrl_jump;

// ID/EX Pipeline Register
reg        id_ex_reg_dst;
reg        id_ex_alu_src;
reg        id_ex_mem_to_reg;
reg        id_ex_reg_write;
reg        id_ex_mem_read;   // single declaration here
reg        id_ex_mem_write;
reg [1:0]  id_ex_alu_op;
reg [15:0] id_ex_pc;
reg [15:0] id_ex_rd1;
reg [15:0] id_ex_rd2;
reg [15:0] id_ex_imm_se;
reg [2:0]  id_ex_rs;
reg [2:0]  id_ex_rt;         // single declaration here
reg [2:0]  id_ex_rd;
reg [2:0]  id_ex_funct;

// Hazard unit ? uses id_ex_mem_read and id_ex_rt
wire flush_ex;

hazard_unit u_hazard (
    .id_ex_mem_read (id_ex_mem_read),
    .id_ex_rt       (id_ex_rt),
    .if_id_rs       (id_rs),
    .if_id_rt       (id_rt),
    .branch_taken   (branch_taken),
    .jump           (ctrl_jump),
    .stall          (stall),
    .flush_ex       (flush_ex),
    .flush_if       (flush_if)
);

always @(posedge clk) begin
    if (reset || flush_ex) begin
        id_ex_reg_dst    <= 0;
        id_ex_alu_src    <= 0;
        id_ex_mem_to_reg <= 0;
        id_ex_reg_write  <= 0;
        id_ex_mem_read   <= 0;
        id_ex_mem_write  <= 0;
        id_ex_alu_op     <= 0;
        id_ex_pc         <= 0;
        id_ex_rd1        <= 0;
        id_ex_rd2        <= 0;
        id_ex_imm_se     <= 0;
        id_ex_rs         <= 0;
        id_ex_rt         <= 0;
        id_ex_rd         <= 0;
        id_ex_funct      <= 0;
    end
    else if (!stall) begin
        id_ex_reg_dst    <= ctrl_reg_dst;
        id_ex_alu_src    <= ctrl_alu_src;
        id_ex_mem_to_reg <= ctrl_mem_to_reg;
        id_ex_reg_write  <= ctrl_reg_write;
        id_ex_mem_read   <= ctrl_mem_read;
        id_ex_mem_write  <= ctrl_mem_write;
        id_ex_alu_op     <= ctrl_alu_op;
        id_ex_pc         <= if_id_pc;
        id_ex_rd1        <= rf_rd1;
        id_ex_rd2        <= rf_rd2;
        id_ex_imm_se     <= id_imm_se;
        id_ex_rs         <= id_rs;
        id_ex_rt         <= id_rt;
        id_ex_rd         <= id_rd;
        id_ex_funct      <= id_funct;
    end
end

// =============================================================================
// STAGE 3 ? EX: Execute
// =============================================================================
wire [2:0]  ex_alu_ctrl;
wire [15:0] ex_alu_b      = id_ex_alu_src ? id_ex_imm_se : id_ex_rd2;
wire [15:0] ex_result;
wire        ex_zero;
wire [2:0]  ex_write_reg  = id_ex_reg_dst ? id_ex_rd : id_ex_rt;

alu_control u_alu_ctrl (
    .alu_op  (id_ex_alu_op),
    .funct   (id_ex_funct),
    .alu_ctrl(ex_alu_ctrl)
);

mips_alu u_alu (
    .a       (id_ex_rd1),
    .b       (ex_alu_b),
    .alu_ctrl(ex_alu_ctrl),
    .result  (ex_result),
    .zero    (ex_zero)
);

// EX/WB Pipeline Register
reg        ex_wb_mem_to_reg;
reg        ex_wb_reg_write;
reg        ex_wb_mem_read;
reg        ex_wb_mem_write;
reg [15:0] ex_wb_alu_result;
reg [15:0] ex_wb_rd2;
reg [2:0]  ex_wb_write_reg;

always @(posedge clk) begin
    if (reset) begin
        ex_wb_mem_to_reg  <= 0;
        ex_wb_reg_write   <= 0;
        ex_wb_mem_read    <= 0;
        ex_wb_mem_write   <= 0;
        ex_wb_alu_result  <= 0;
        ex_wb_rd2         <= 0;
        ex_wb_write_reg   <= 0;
    end
    else begin
        ex_wb_mem_to_reg  <= id_ex_mem_to_reg;
        ex_wb_reg_write   <= id_ex_reg_write;
        ex_wb_mem_read    <= id_ex_mem_read;
        ex_wb_mem_write   <= id_ex_mem_write;
        ex_wb_alu_result  <= ex_result;
        ex_wb_rd2         <= id_ex_rd2;
        ex_wb_write_reg   <= ex_write_reg;
    end
end

// =============================================================================
// STAGE 4 ? WB: Memory + Writeback
// =============================================================================
wire [15:0] wb_mem_data;

data_mem u_dmem (
    .clk       (clk),
    .mem_write (ex_wb_mem_write),
    .mem_read  (ex_wb_mem_read),
    .addr      (ex_wb_alu_result),
    .write_data(ex_wb_rd2),
    .read_data (wb_mem_data)
);

assign wb_write_data = ex_wb_mem_to_reg ? wb_mem_data : ex_wb_alu_result;
assign wb_reg_write  = ex_wb_reg_write;
assign wb_write_reg  = ex_wb_write_reg;

endmodule