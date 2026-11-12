# 16-bit 4-stage pipelined CPU

A small 16-bit processor with its own instruction set, 8 registers (R0 is fixed at 0), and a 4-stage pipeline: fetch (IF), decode (ID), execute (EX) and write-back (WB). The full instruction set, encodings and hazard rules are in [docs/isa.md](docs/isa.md).

## Instruction set (summary)

ADD, SUB, AND, OR, XOR, ADDI, LW, SW, BEQ, JMP, NOP, HALT. Instructions are 16 bits: a 4-bit opcode followed by register fields and either a third register, a signed 6-bit immediate, or a 12-bit jump address.

## Pipeline

| Stage | What happens |
|---|---|
| IF | read the instruction at the PC, PC + 1 |
| ID | decode, read registers, check for data hazards |
| EX | ALU, data memory access for LW/SW, decide BEQ/JMP |
| WB | write the result into the register file |

Pipeline registers sit between the stages (IF/ID, ID/EX, EX/WB). Each one carries a `valid` bit, so empty slots (bubbles) and flushed instructions are never counted as finished.

## Hazards

This version has no forwarding, so hazards are handled by stalling and flushing:

- **Data hazard**: if the instruction in ID needs a register that the instruction in EX is about to write, the CPU stalls for one cycle. It holds the PC and IF/ID, and sends a bubble into EX. The hazard check only looks at the registers an instruction actually uses, and ignores R0.
- **WB write-through**: if the value an instruction needs is being written back in the same cycle, the register read passes that value straight through, so no stall is needed.
- **Control hazard**: BEQ and JMP are decided in EX. If the branch is taken, the two younger instructions already in IF and ID are flushed (turned into NOPs), which costs 2 cycles. A branch that isn't taken costs nothing.
- **HALT**: when HALT reaches EX, fetching stops and younger instructions are flushed. `halted` goes high once HALT finishes WB.

## Files

- `rtl/pipelined_cpu.v`: the CPU
- `tb/tb_pipelined_cpu.v`: testbench
- `sim/prog1.hex` … `prog4.hex`: test programs (`program.hex` is a copy of prog1, the default)
- `sim/run.do`: ModelSim script
- `docs/isa.md`: instruction set and pipeline details

## How I tested it

The testbench runs four CPUs side by side, one per test program, and checks the final register values once they've all halted. It also counts clock cycles and finished instructions for each program and prints the CPI (cycles per instruction).

| Program | What it tests | Result |
|---|---|---|
| prog1 | a loop adding 10 down to 1 | R1 = 55, 41 instructions |
| prog2 | back-to-back dependent instructions (stalls) and a distance-2 dependency (write-through) | 10 instructions in 15 cycles |
| prog3 | a BEQ not taken, a BEQ taken and a JMP, with the instructions after them flushed | 8 instructions in 15 cycles |
| prog4 | AND/OR/XOR, SW then LW, load-use stalls, and a write to R0 that must be ignored | R0 stays 0, all values correct |

```
Program 1: cycles=75 instructions=41 CPI=1.829268
Program 2: cycles=15 instructions=10 CPI=1.500000
Program 3: cycles=15 instructions=8 CPI=1.875000
Program 4: cycles=19 instructions=13 CPI=1.461538
ALL TESTS PASSED
```

These CPI numbers are the starting point for the next version, which adds forwarding and branch prediction.

To run: `cd sim` then `vsim -do run.do` (run from `sim/` so the `.hex` files are found).

![waveform](docs/waveform.png)
