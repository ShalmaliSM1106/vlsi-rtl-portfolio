# SPI master

An SPI master for 8-bit transfers in mode 0, written as a state machine (IDLE → TRANSFER → DONE).

SPI uses four wires: `sclk` (the clock, driven by the master), `mosi` (master out, slave in), `miso` (master in, slave out) and `cs_n` (chip select, active low). Each `sclk` cycle sends one bit and receives one bit at the same time, so a transfer always swaps a byte in each direction.

**Mode 0** (CPOL = 0, CPHA = 0): `sclk` idles low, data is sampled on the rising edge and changed on the falling edge. The most significant bit goes first.

## How it works

- `CLK_DIV` sets the speed: it's the number of system clocks per half `sclk` period, so `sclk` = system clock ÷ (2 × `CLK_DIV`).
- On `start`, the master pulls `cs_n` low, loads `tx_byte` into a shift register and puts the top bit on `mosi` straight away, so it's ready before the first rising edge.
- In TRANSFER, `sclk` toggles every `CLK_DIV` clocks, 16 times in total (8 bits):
  - rising edge: `miso` is shifted into the receive register
  - falling edge: the next bit is put on `mosi`
- After the 16th toggle, DONE raises `cs_n`, puts the received byte on `rx_byte`, and pulses `done` for one clock.
- `busy` is high for the whole transfer.

## Files

- `rtl/spi_master.v`: the design
- `tb/tb_spi_master.v`: testbench
- `sim/run.do`: ModelSim script

## How I tested it

The testbench includes a simple mode-0 slave model. It sends a known byte back on `miso` and captures whatever arrives on `mosi`, so both directions are checked in every transfer:

- the master's `rx_byte` equals the byte the slave sent
- the slave received the master's `tx_byte`
- exactly 8 rising edges on `sclk`
- `busy` and `cs_n` behave correctly during and after the transfer, `sclk` returns low, and `done` is a single-clock pulse

It runs 6 directed byte pairs (including `0x00`/`0xFF` and alternating patterns) and 100 random pairs. It also passes with `CLK_DIV` set to 1, 2, 3, 4 and 7.

```
ALL TESTS PASSED
```

To run: `cd sim` then `vsim -do run.do`

![waveform](docs/waveform.png)
