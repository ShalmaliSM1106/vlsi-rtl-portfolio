`timescale 1ns/1ps
// Runs four programs in parallel on four CPU instances (one program each).
// Run the simulation from this folder so prog1.hex ... prog4.hex are found.
module tb_pipelined_cpu;

    localparam NPROG = 4;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    wire [NPROG-1:0]     halted_w;
    wire [NPROG-1:0]     retired_w;
    wire [NPROG*128-1:0] regs_all;

    genvar g;
    generate
        for (g = 0; g < NPROG; g = g + 1) begin : cpu
            pipelined_cpu #(
                .PROGRAM((g == 0) ? "prog1.hex" :
                         (g == 1) ? "prog2.hex" :
                         (g == 2) ? "prog3.hex" : "prog4.hex")
            ) dut (
                .clk(clk), .rst(rst),
                .halted(halted_w[g]),
                .retired(retired_w[g]),
                .dbg_regs(regs_all[g*128 +: 128])
            );
        end
    endgenerate

    // ---------------- self-checking infrastructure ----------------
    integer errors = 0;
    task check(input [31:0] got, input [31:0] exp, input [8*20:1] msg);
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL %s: got %h, expected %h", msg, got, exp);
        end
    endtask

    // register r of program prog (0-based)
    function [15:0] R(input integer prog, input integer r);
        R = regs_all[prog*128 + r*16 +: 16];
    endfunction

    // ---------------- cycle / instruction counters ----------------
    // cycles : clocks from reset release until HALT completes WB
    // instrs : real instructions retired (bubbles and flushed instructions excluded)
    integer cycles [0:NPROG-1];
    integer instrs [0:NPROG-1];
    integer pi;

    always @(posedge clk) begin
        if (!rst) begin
            for (pi = 0; pi < NPROG; pi = pi + 1) begin
                if (halted_w[pi] === 1'b0) begin
                    cycles[pi] = cycles[pi] + 1;
                    if (retired_w[pi]) instrs[pi] = instrs[pi] + 1;
                end
            end
        end
    end

    integer q;
    integer timeout;

    initial begin
        for (q = 0; q < NPROG; q = q + 1) begin
            cycles[q] = 0;
            instrs[q] = 0;
        end

        rst = 1;
        repeat (4) @(negedge clk);
        rst = 0;

        timeout = 0;
        while (halted_w !== {NPROG{1'b1}} && timeout < 5000) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        check(timeout < 5000, 1, "all CPUs halted");
        @(negedge clk);

        // ---------- Program 1: sum 1..10 ----------
        check(R(0,1), 55, "P1 R1 = 55");
        check(R(0,2), 0,  "P1 R2 = 0");
        check(R(0,0), 0,  "P1 R0 = 0");
        check(instrs[0], 41, "P1 retired count");

        // ---------- Program 2: dependent instructions (stall) ----------
        check(R(1,2), 4,  "P2 R2 = 4");
        check(R(1,5), 2,  "P2 R5 = 2");
        check(R(1,1), 12, "P2 R1 = R2+R3");
        check(R(1,4), 10, "P2 R4 = R1-R5");
        check(R(1,6), 20, "P2 R6 = R4+R4");
        check(R(1,3), 3,  "P2 R3 = 3");
        check(R(1,7), 6,  "P2 WB bypass R7");
        check(instrs[1], 10, "P2 retired count");
        check(cycles[1], 15, "P2 cycles");        // 10 + 3 fill + 2 stalls

        // ---------- Program 3: taken branch / flush ----------
        check(R(2,1), 1, "P3 R1 = 1");
        check(R(2,2), 1, "P3 R2 = 1");
        check(R(2,3), 3, "P3 not-taken ok");
        check(R(2,4), 0, "P3 R4 flushed (ID)");
        check(R(2,5), 0, "P3 R5 flushed (IF)");
        check(R(2,6), 7, "P3 target ran");
        check(R(2,7), 0, "P3 JMP flushed");
        check(instrs[2], 8, "P3 retired count");
        check(cycles[2], 15, "P3 cycles");        // 8 + 3 fill + 2 taken x 2 flush

        // ---------- Program 4: logic ops, LW/SW, load-use, R0 ----------
        check(R(3,0), 0,  "P4 R0 stays zero");
        check(R(3,1), 14, "P4 R1 (LW)");
        check(R(3,2), 8,  "P4 R2 = R7-R1");
        check(R(3,3), 8,  "P4 R3 = AND");
        check(R(3,4), 14, "P4 R4 = OR");
        check(R(3,5), 6,  "P4 R5 = XOR");
        check(R(3,6), 8,  "P4 R6 (LW)");
        check(R(3,7), 22, "P4 R7 = R6+R4");
        check(instrs[3], 13, "P4 retired count");

        // ---------- performance summary (baseline for forwarding upgrade) ----------
        for (q = 0; q < NPROG; q = q + 1)
            $display("Program %0d: cycles=%0d instructions=%0d CPI=%f",
                     q+1, cycles[q], instrs[q], $itor(cycles[q]) / $itor(instrs[q]));

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule
