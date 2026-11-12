# ALU

A combinational ALU with a parameter for data width (`WIDTH`, default 8). It takes two operands and a 4-bit opcode, and outputs the result plus four status flags.

## Operations

| op | Operation | Notes |
|---|---|---|
| 0 | ADD | `carry` = carry out, `overflow` = signed overflow |
| 1 | SUB | `carry` = borrow (set when a < b, unsigned), `overflow` = signed overflow |
| 2 | AND | |
| 3 | OR | |
| 4 | XOR | |
| 5 | NOT | ~a |
| 6 | SLL | a << b |
| 7 | SRL | a >> b (logical) |
| 8 | SLT | 1 if a < b (signed), else 0 |
| 9–15 | unused | result = 0 |

## Flags

- `zero`: result is 0
- `negative`: top bit of the result
- `carry`: carry out for ADD, borrow for SUB, 0 otherwise
- `overflow`: signed overflow for ADD and SUB. For ADD it's set when a and b have the same sign but the result's sign is different. For SUB it's set when a and b have different signs and the result's sign differs from a.

All outputs get a default value at the top of the `always @(*)` block, so the design doesn't infer any latches.

## Files

- `rtl/alu.v`: the ALU
- `tb/tb_alu.v`: testbench
- `sim/run.do`: ModelSim script

## How I tested it

The testbench runs the ALU at `WIDTH = 4` and tries every opcode (all 16) with every possible pair of inputs, which is 4,096 cases. For each case it works out the expected result and flags separately, using ordinary Verilog operators and signed integers for the overflow check, then compares all five outputs. That's 20,480 checks in total, and it prints any mismatch plus a pass/fail summary at the end.

```
Ran 20480 checks
ALL TESTS PASSED
```

To run: `cd sim` then `vsim -do run.do`

![waveform](docs/waveform.png)
