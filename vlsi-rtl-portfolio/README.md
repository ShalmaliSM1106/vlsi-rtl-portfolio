# vlsi-rtl-portfolio

A set of digital design blocks I wrote in Verilog to practise RTL design and verification. Each block is in its own folder with the RTL, a testbench, a ModelSim script and a short README with waveforms.

I started this to go beyond what we did in labs. Lab exercises usually stop once the waveform "looks right", so for these I tried to write testbenches that check the outputs on their own wherever I could.

## Blocks

| Block | What it is |
|---|---|
| [Parameterized ALU](alu/) | An ALU with a parameter for data width. |
| [Universal shift register](shift_register/) | A shift register that can hold, shift left, shift right or load in parallel, chosen by a 2-bit mode input. |
| [UART transmitter and receiver](uart/) | A UART TX and RX written as state machines (idle, start bit, data bits, stop bit). |
| [Synchronous FIFO](sync_fifo/) | A FIFO with one clock for read and write, a parameter for depth and width, and full/empty flags. |
| [SPI master](spi_master/) | An SPI master written as a state machine. |
| [Pipelined FIR filter](fir_filter/) | A [N]-tap FIR filter with pipeline registers between the multiply and add stages so it can run at a higher clock speed. |
| [16-bit 4-stage pipelined CPU](pipelined_cpu/) | A 16-bit processor with a 4-stage pipeline ([stage names, e. |

## Tools

- Verilog HDL
- ModelSim for simulation
- Xilinx Vivado for synthesis ([board/part, e.g. Artix-7])

## How to run any block

```
cd <block>/sim
vsim -do run.do
```

## What I'm adding next

- an I2C master, so UART, SPI and I2C are all covered
- forwarding and branch prediction for the CPU
- a SystemVerilog testbench for the FIFO with random tests and coverage

Shalmali Mankikar · [LinkedIn](https://www.linkedin.com/in/shalmali-mankikar)
