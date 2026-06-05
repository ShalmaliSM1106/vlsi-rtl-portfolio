// =============================================================================
// Module      : tb_mips_cpu
// Description : Testbench for 16-bit Pipelined MIPS CPU
// =============================================================================

`timescale 1ns/1ps

module tb_mips_cpu;

parameter CLK_PERIOD = 10;

reg clk;
reg reset;

mips_cpu dut (
    .clk  (clk),
    .reset(reset)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

integer pass_count;
integer fail_count;
integer total;
integer timeout;

task check_reg;
    input [2:0]  reg_num;
    input [15:0] exp_val;
    input [63:0] test_id;
    reg   [15:0] got;
    begin
        got = dut.u_rf.registers[reg_num];
        if (got !== exp_val) begin
            $display("FAIL [Test %0d] r%0d = %0d (0x%h), expected %0d (0x%h)",
                test_id, reg_num, got, got, exp_val, exp_val);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS [Test %0d] r%0d = %0d", test_id, reg_num, got);
            pass_count = pass_count + 1;
        end
        total = total + 1;
    end
endtask

task check_mem;
    input [7:0]  addr;
    input [15:0] exp_val;
    input [63:0] test_id;
    reg   [15:0] got;
    begin
        got = dut.u_dmem.mem[addr];
        if (got !== exp_val) begin
            $display("FAIL [Test %0d] mem[%0d] = %0d, expected %0d",
                test_id, addr, got, exp_val);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS [Test %0d] mem[%0d] = %0d", test_id, addr, got);
            pass_count = pass_count + 1;
        end
        total = total + 1;
    end
endtask

initial begin
    pass_count = 0;
    fail_count = 0;
    total      = 0;
    timeout    = 0;

    $readmemh("program.hex", dut.u_imem.mem);

    reset = 1;
    repeat(4) @(posedge clk);
    reset = 0;

    $display("=============================================================");
    $display("  MIPS CPU Testbench");
    $display("=============================================================");

    // Wait until mem[0] has been written by SW (value = 8)
    // This guarantees SW has completed before we check anything
    $display("  Waiting for SW to write mem[0]...");
    timeout = 0;
    while (dut.u_dmem.mem[0] !== 16'd8 && timeout < 500) begin
        @(posedge clk);
        timeout = timeout + 1;
    end

    if (timeout >= 500) begin
        $display("TIMEOUT: SW never wrote mem[0]");
        $finish;
    end
    $display("  SW complete at cycle ~%0d", timeout);

    // Now wait for LW to write r1 = 8
    // LW comes after SW ? poll until r1 == 8
    $display("  Waiting for LW to write r1=8...");
    timeout = 0;
    while (dut.u_rf.registers[1] !== 16'd8 && timeout < 500) begin
        @(posedge clk);
        timeout = timeout + 1;
    end

    if (timeout >= 500) begin
        $display("TIMEOUT: LW never wrote r1=8");
        $finish;
    end
    $display("  LW complete at cycle ~%0d", timeout);

    // Extra few cycles for pipeline to fully settle
    repeat(5) @(posedge clk);

    $display("--- Checking Register File ---");
    check_reg(1, 16'd8,  1);
    check_reg(2, 16'd3,  2);
    check_reg(3, 16'd8,  3);
    check_reg(4, 16'd2,  4);
    check_reg(5, 16'd1,  5);
    check_reg(6, 16'd7,  6);
    check_reg(7, 16'd1,  7);

    $display("--- Checking Data Memory ---");
    check_mem(0, 16'd8,  8);

    $display("=============================================================");
    $display("  TEST SUMMARY");
    $display("  Total  : %0d", total);
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    if (fail_count == 0)
        $display("  STATUS : ALL TESTS PASSED");
    else
        $display("  STATUS : SOME TESTS FAILED - review output above");
    $display("=============================================================");

    $finish;
end

always @(posedge clk) begin
    if (!reset)
        $display("  [cyc %0t] PC=%0d  INSTR=%h",
            $time, dut.u_pc.pc, dut.if_id_instr);
end

endmodule