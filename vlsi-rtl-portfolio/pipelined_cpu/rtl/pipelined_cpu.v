`timescale 1ns/1ps
// 16-bit, 4-stage pipelined CPU: IF -> ID -> EX -> WB
//   IF : fetch imem[PC], PC+1
//   ID : decode, read registers (with WB write-through bypass), hazard detection
//   EX : ALU, data-memory access (LW/SW), branch/jump decision
//   WB : write result to register file
// Pipeline registers: IF/ID, ID/EX, EX/WB.
//
// Hazards (no forwarding in this version):
//   * Data hazard : ID source == EX destination  -> stall 1 cycle (hold PC and IF/ID,
//                   insert a bubble into ID/EX).
//   * WB hazard   : register file read in ID passes through the value being written
//                   in WB the same cycle (write-through), so no stall is needed.
//   * Control     : BEQ/JMP are resolved in EX. If taken, IF/ID and ID/EX are flushed
//                   (2-cycle penalty) and the PC is loaded with the target.
// R0 is hardwired to zero (writes ignored, reads return 0).
// Reset: synchronous, active-high.
//
// Test/debug ports: halted, retired (instruction-complete strobe), dbg_regs.
module pipelined_cpu #(
    parameter PROGRAM = "program.hex"
)(
    input          clk,
    input          rst,
    output reg     halted,      // goes high once HALT has completed WB
    output         retired,     // high when a real (non-bubble) instruction is in WB
    output [127:0] dbg_regs     // {R7,R6,R5,R4,R3,R2,R1,R0}
);

    // ---------------- opcodes ----------------
    localparam OP_NOP  = 4'h0;
    localparam OP_ADD  = 4'h1;
    localparam OP_SUB  = 4'h2;
    localparam OP_AND  = 4'h3;
    localparam OP_OR   = 4'h4;
    localparam OP_XOR  = 4'h5;
    localparam OP_ADDI = 4'h6;
    localparam OP_LW   = 4'h7;
    localparam OP_SW   = 4'h8;
    localparam OP_BEQ  = 4'h9;
    localparam OP_JMP  = 4'hA;
    localparam OP_HALT = 4'hF;

    // ALU operations
    localparam ALU_ADD = 3'd0;
    localparam ALU_SUB = 3'd1;
    localparam ALU_AND = 3'd2;
    localparam ALU_OR  = 3'd3;
    localparam ALU_XOR = 3'd4;

    // ---------------- memories ----------------
    reg [15:0] imem     [0:255];
    reg [15:0] dmem     [0:255];
    reg [15:0] regfile  [0:7];

    integer k;
    integer i;

    initial begin
        for (k = 0; k < 256; k = k + 1) begin
            imem[k] = 16'h0000;       // unused locations are NOPs
            dmem[k] = 16'h0000;
        end
        $readmemh(PROGRAM, imem);
    end

    // ---------------- pipeline registers ----------------
    reg [15:0] pc;

    // IF/ID
    reg [15:0] ifid_instr;
    reg [15:0] ifid_pc1;              // address of this instruction + 1
    reg        ifid_valid;

    // ID/EX
    reg        idex_valid;
    reg        idex_reg_write;
    reg        idex_mem_read;
    reg        idex_mem_write;
    reg        idex_alu_src_imm;
    reg        idex_is_beq;
    reg        idex_is_jmp;
    reg        idex_is_halt;
    reg [2:0]  idex_alu_op;
    reg [2:0]  idex_rd;
    reg [15:0] idex_a;
    reg [15:0] idex_b;
    reg [15:0] idex_imm;
    reg [15:0] idex_pc1;
    reg [15:0] idex_jtarget;

    // EX/WB
    reg        exwb_valid;
    reg        exwb_reg_write;
    reg        exwb_halt;
    reg [2:0]  exwb_rd;
    reg [15:0] exwb_result;

    reg        halting;               // sticky: HALT has been seen in EX, stop fetching

    // =====================================================================
    // IF stage
    // =====================================================================
    wire [15:0] if_instr = imem[pc[7:0]];

    // =====================================================================
    // ID stage: decode
    // =====================================================================
    wire [3:0]  id_op  = ifid_instr[15:12];
    wire [2:0]  id_rd  = ifid_instr[11:9];
    wire [2:0]  id_ra  = ifid_instr[8:6];
    // second source: SW (store data) and BEQ use [11:9]; R-type uses [5:3]
    wire [2:0]  id_rb  = (id_op == OP_SW || id_op == OP_BEQ) ? ifid_instr[11:9]
                                                             : ifid_instr[5:3];
    wire [15:0] id_imm     = {{10{ifid_instr[5]}}, ifid_instr[5:0]};   // sign-extended imm6
    wire [15:0] id_jtarget = {4'b0000, ifid_instr[11:0]};

    reg       id_reg_write;
    reg       id_use_a;
    reg       id_use_b;
    reg       id_mem_read;
    reg       id_mem_write;
    reg       id_alu_src_imm;
    reg       id_is_beq;
    reg       id_is_jmp;
    reg       id_is_halt;
    reg [2:0] id_alu_op;

    always @(*) begin
        id_reg_write   = 1'b0;
        id_use_a       = 1'b0;
        id_use_b       = 1'b0;
        id_mem_read    = 1'b0;
        id_mem_write   = 1'b0;
        id_alu_src_imm = 1'b0;
        id_is_beq      = 1'b0;
        id_is_jmp      = 1'b0;
        id_is_halt     = 1'b0;
        id_alu_op      = ALU_ADD;
        case (id_op)
            OP_ADD:  begin id_reg_write = 1'b1; id_use_a = 1'b1; id_use_b = 1'b1; id_alu_op = ALU_ADD; end
            OP_SUB:  begin id_reg_write = 1'b1; id_use_a = 1'b1; id_use_b = 1'b1; id_alu_op = ALU_SUB; end
            OP_AND:  begin id_reg_write = 1'b1; id_use_a = 1'b1; id_use_b = 1'b1; id_alu_op = ALU_AND; end
            OP_OR:   begin id_reg_write = 1'b1; id_use_a = 1'b1; id_use_b = 1'b1; id_alu_op = ALU_OR;  end
            OP_XOR:  begin id_reg_write = 1'b1; id_use_a = 1'b1; id_use_b = 1'b1; id_alu_op = ALU_XOR; end
            OP_ADDI: begin id_reg_write = 1'b1; id_use_a = 1'b1; id_alu_src_imm = 1'b1; end
            OP_LW:   begin id_reg_write = 1'b1; id_use_a = 1'b1; id_alu_src_imm = 1'b1; id_mem_read = 1'b1; end
            OP_SW:   begin id_use_a = 1'b1; id_use_b = 1'b1; id_alu_src_imm = 1'b1; id_mem_write = 1'b1; end
            OP_BEQ:  begin id_use_a = 1'b1; id_use_b = 1'b1; id_is_beq = 1'b1; end
            OP_JMP:  id_is_jmp  = 1'b1;
            OP_HALT: id_is_halt = 1'b1;
            default: ;   // NOP / unknown opcode: behaves as NOP
        endcase
    end

    // ---------------- register read with WB write-through ----------------
    wire        wb_we   = exwb_reg_write && (exwb_rd != 3'd0);
    wire [15:0] wb_data = exwb_result;

    reg [15:0] id_a_val;
    reg [15:0] id_b_val;

    always @(*) begin
        id_a_val = 16'h0000;
        id_b_val = 16'h0000;
        if (id_ra != 3'd0)
            id_a_val = (wb_we && exwb_rd == id_ra) ? wb_data : regfile[id_ra];
        if (id_rb != 3'd0)
            id_b_val = (wb_we && exwb_rd == id_rb) ? wb_data : regfile[id_rb];
    end

    // ---------------- data hazard detection (ID vs EX) ----------------
    wire stall = idex_reg_write && (idex_rd != 3'd0) &&
                 ((id_use_a && (id_ra == idex_rd)) ||
                  (id_use_b && (id_rb == idex_rd)));

    // =====================================================================
    // EX stage
    // =====================================================================
    reg [15:0] alu_b;
    reg [15:0] alu_out;

    always @(*) begin
        alu_b   = idex_alu_src_imm ? idex_imm : idex_b;
        alu_out = 16'h0000;
        case (idex_alu_op)
            ALU_ADD: alu_out = idex_a + alu_b;
            ALU_SUB: alu_out = idex_a - alu_b;
            ALU_AND: alu_out = idex_a & alu_b;
            ALU_OR:  alu_out = idex_a | alu_b;
            ALU_XOR: alu_out = idex_a ^ alu_b;
            default: alu_out = 16'h0000;
        endcase
    end

    wire [7:0]  ex_addr   = alu_out[7:0];                       // word address
    wire [15:0] ex_result = idex_mem_read ? dmem[ex_addr] : alu_out;

    wire        ex_eq     = (idex_a == idex_b);
    wire        ex_taken  = idex_valid && ((idex_is_beq && ex_eq) || idex_is_jmp);
    wire [15:0] ex_target = idex_is_jmp ? idex_jtarget : (idex_pc1 + idex_imm);
    wire        ex_halt   = idex_valid && idex_is_halt;

    wire        stop      = ex_halt || halting;                 // stop fetching/issuing

    // =====================================================================
    // Sequential logic
    // =====================================================================
    always @(posedge clk) begin
        if (rst) begin
            pc               <= 16'h0000;
            ifid_instr       <= 16'h0000;
            ifid_pc1         <= 16'h0000;
            ifid_valid       <= 1'b0;
            idex_valid       <= 1'b0;
            idex_reg_write   <= 1'b0;
            idex_mem_read    <= 1'b0;
            idex_mem_write   <= 1'b0;
            idex_alu_src_imm <= 1'b0;
            idex_is_beq      <= 1'b0;
            idex_is_jmp      <= 1'b0;
            idex_is_halt     <= 1'b0;
            idex_alu_op      <= ALU_ADD;
            idex_rd          <= 3'd0;
            idex_a           <= 16'h0000;
            idex_b           <= 16'h0000;
            idex_imm         <= 16'h0000;
            idex_pc1         <= 16'h0000;
            idex_jtarget     <= 16'h0000;
            exwb_valid       <= 1'b0;
            exwb_reg_write   <= 1'b0;
            exwb_halt        <= 1'b0;
            exwb_rd          <= 3'd0;
            exwb_result      <= 16'h0000;
            halting          <= 1'b0;
            halted           <= 1'b0;
            for (i = 0; i < 8; i = i + 1)
                regfile[i] <= 16'h0000;
        end else begin
            // ---------------- WB ----------------
            if (wb_we)
                regfile[exwb_rd] <= exwb_result;
            if (exwb_valid && exwb_halt)
                halted <= 1'b1;

            // ---------------- EX ----------------
            if (idex_valid && idex_mem_write)
                dmem[ex_addr] <= idex_b;           // SW: store data is operand B

            exwb_valid     <= idex_valid;
            exwb_reg_write <= idex_reg_write;
            exwb_halt      <= idex_is_halt;
            exwb_rd        <= idex_rd;
            exwb_result    <= ex_result;

            if (ex_halt)
                halting <= 1'b1;

            // ---------------- PC ----------------
            if (ex_taken)
                pc <= ex_target;                   // taken branch/jump wins
            else if (stall || stop)
                pc <= pc;                          // hold during stall / halt
            else
                pc <= pc + 16'd1;

            // ---------------- IF/ID ----------------
            if (ex_taken || stop) begin            // flush
                ifid_instr <= 16'h0000;
                ifid_pc1   <= 16'h0000;
                ifid_valid <= 1'b0;
            end else if (!stall) begin             // normal advance (hold on stall)
                ifid_instr <= if_instr;
                ifid_pc1   <= pc + 16'd1;
                ifid_valid <= 1'b1;
            end

            // ---------------- ID/EX ----------------
            if (ex_taken || stop || stall) begin   // bubble (NOP)
                idex_valid       <= 1'b0;
                idex_reg_write   <= 1'b0;
                idex_mem_read    <= 1'b0;
                idex_mem_write   <= 1'b0;
                idex_alu_src_imm <= 1'b0;
                idex_is_beq      <= 1'b0;
                idex_is_jmp      <= 1'b0;
                idex_is_halt     <= 1'b0;
                idex_alu_op      <= ALU_ADD;
                idex_rd          <= 3'd0;
                idex_a           <= 16'h0000;
                idex_b           <= 16'h0000;
                idex_imm         <= 16'h0000;
                idex_pc1         <= 16'h0000;
                idex_jtarget     <= 16'h0000;
            end else begin
                idex_valid       <= ifid_valid;
                idex_reg_write   <= id_reg_write;
                idex_mem_read    <= id_mem_read;
                idex_mem_write   <= id_mem_write;
                idex_alu_src_imm <= id_alu_src_imm;
                idex_is_beq      <= id_is_beq;
                idex_is_jmp      <= id_is_jmp;
                idex_is_halt     <= id_is_halt;
                idex_alu_op      <= id_alu_op;
                idex_rd          <= id_rd;
                idex_a           <= id_a_val;
                idex_b           <= id_b_val;
                idex_imm         <= id_imm;
                idex_pc1         <= ifid_pc1;
                idex_jtarget     <= id_jtarget;
            end
        end
    end

    assign retired  = exwb_valid;
    assign dbg_regs = {regfile[7], regfile[6], regfile[5], regfile[4],
                       regfile[3], regfile[2], regfile[1], regfile[0]};

endmodule
