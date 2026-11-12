# Universal shift register

An N-bit register (`N`, default 8) that can hold its value, shift right, shift left or load a new value in parallel, chosen by a 2-bit `mode` input. Reset is synchronous and active-high, and it takes priority over every mode.

| mode | Operation | Next value of q |
|---|---|---|
| 00 | hold | `q` |
| 01 | shift right | `{sin_right, q[N-1:1]}`: `sin_right` enters at the top bit |
| 10 | shift left | `{q[N-2:0], sin_left}`: `sin_left` enters at bit 0 |
| 11 | parallel load | `d` |

## Files

- `rtl/shift_register.v`: the design
- `tb/tb_shift_register.v`: testbench
- `sim/run.do`: ModelSim script

## How I tested it

The testbench keeps its own expected copy of `q`, updated on every rising edge from the same inputs. Inputs change on the falling edge, and `q` is checked 1 ns after each rising edge, so there are no races between the testbench and the design.

It covers:
- reset, including reset winning over a load and a reset in the middle of shifting
- load followed by several hold cycles
- shifting right until the register is full of 1s, then full of 0s
- shifting a known pattern in from the left (`0x01` becomes `0x15`)
- back-to-back mode changes
- 500 cycles of random modes and inputs

```
Ran 561 checks
ALL TESTS PASSED
```

To run: `cd sim` then `vsim -do run.do`

![waveform](docs/waveform.png)
