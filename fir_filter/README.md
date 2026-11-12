# Pipelined FIR filter

A 4-tap FIR filter with signed inputs and a pipelined datapath. Each output is a weighted sum of the four most recent input samples:

y[n] = h0·x[n] + h1·x[n−1] + h2·x[n−2] + h3·x[n−3]

The coefficients are fixed at h = {1, 2, 3, 4}. Input and coefficient widths are parameters (`DW` = 8, `CW` = 8). The output is `DW + CW + log2(TAPS)` = 18 bits wide, so it can't overflow.

## Pipeline

| Stage | What happens |
|---|---|
| 0 | the new sample shifts into a register holding the last 4 samples (only when `in_valid` is high) |
| 1 | each sample is multiplied by its coefficient, and the products are registered |
| 2 | products are added in pairs, and the pair sums are registered |
| 3 | the pair sums are added, and the result is registered as `y_out` |

Without these registers, one clock period would have to cover a multiply plus every addition. Splitting the work across stages means each stage does less, so the clock can run faster. The cost is latency: an output appears **4 clocks** after its input.

`in_valid` travels down its own 4-stage shift register, so `out_valid` lines up exactly with the matching `y_out`. Gaps in the input (cycles with `in_valid` low) are handled correctly.

All the data registers are declared `signed`, so negative samples are multiplied and added correctly.

The pair-adder structure assumes an even number of taps.

## Files

- `rtl/fir_filter.v`: the design
- `tb/tb_fir_filter.v`: testbench
- `sim/run.do`: ModelSim script

## How I tested it

The testbench has a reference model that keeps its own history of valid samples and works out the expected output for every valid input. It only compares when `out_valid` is high, and it flags any `out_valid` that doesn't match a real input.

1. **Impulse** (1, 0, 0, …): the output is the coefficients in order, 1, 2, 3, 4, then 0. This test also checks the latency is exactly 4 clocks.
2. **Step** (1, 1, 1, …): the output builds up 1, 3, 6, 10 and stays at 10.
3. **Extreme values**: a run of −128 (steady output −1280), then alternating −128 and 127.
4. **300 random samples with random gaps** in `in_valid` (about 75% valid)
5. **300 random samples** back to back

```
ALL TESTS PASSED
```

To run: `cd sim` then `vsim -do run.do`

![waveform](docs/waveform.png)
