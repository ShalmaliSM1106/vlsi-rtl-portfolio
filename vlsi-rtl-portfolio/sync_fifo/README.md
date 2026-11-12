# Synchronous FIFO

A first-in, first-out buffer where reads and writes use the same clock. Width and depth are parameters (`WIDTH`, default 8; `DEPTH`, default 16, must be a power of 2). It has `full` and `empty` flags, and it ignores writes when full and reads when empty.

## How it works

- Data is stored in a memory array `mem[0:DEPTH-1]`.
- The write and read pointers are each **one bit wider** than needed to address the memory (5 bits for depth 16). The lower bits pick the memory location. The extra top bit flips every time a pointer wraps around, which is how the FIFO tells "full" apart from "empty":
  - `empty`: the two pointers are exactly equal
  - `full`: the top bits are different and the lower bits are equal, so the write pointer has gone round once more than the read pointer
- A write happens only when `wr_en && !full`, and a read only when `rd_en && !empty`. Reading and writing in the same cycle works.
- `dout` is registered: the data appears one clock after the read is accepted, and it holds its value until the next read.
- The address width comes from a small constant `clog2` function, because Verilog-2001 doesn't have `$clog2`.

## Files

- `rtl/sync_fifo.v`: the design
- `tb/tb_sync_fifo.v`: testbench
- `sim/run.do`: ModelSim script

## How I tested it

The testbench has its own reference model of the FIFO (an array with separate pointers and a count) and compares `full`, `empty` and `dout` against it after every clock. On top of that, it checks:

1. writing until full, and that extra writes are ignored
2. reading until empty, with the data coming out in the right order, and that extra reads are ignored
3. read and write in the same cycle when empty (only the write happens) and when full (only the read happens)
4. read and write every cycle at half full, where the level should stay constant
5. 3,000 cycles of random traffic in six mixes: balanced, mostly writes, mostly reads, both every cycle
6. a reset in the middle of operation

```
Ran 9616 checks
ALL TESTS PASSED
```

It also passes with `DEPTH` set to 2, 4, 8 and 32.

To run: `cd sim` then `vsim -do run.do`

![waveform](docs/waveform.png)
