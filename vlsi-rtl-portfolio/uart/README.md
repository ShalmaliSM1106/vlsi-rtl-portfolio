# UART transmitter and receiver

A UART TX and RX, each written as a state machine. A byte goes out as a start bit (0), 8 data bits with the least significant bit first, and a stop bit (1). The line sits high when idle.

The bit time is set by `CLKS_PER_BIT` = clock frequency ÷ baud rate. For example, a 50 MHz clock at 9600 baud gives 5208. Simulation uses 16 to keep runs short.

## Transmitter (`uart_tx.v`)

States: IDLE → START → DATA → STOP → IDLE.

- A one-clock pulse on `tx_start` copies `tx_data` into an internal register, so the input can change once sending has started.
- Each bit is held on `tx` for `CLKS_PER_BIT` clocks, counted by `clk_cnt`. `bit_idx` tracks which data bit is being sent.
- `tx_busy` stays high for the whole frame, and `tx_start` is ignored while busy.

## Receiver (`uart_rx.v`)

States: IDLE → START → DATA → STOP → IDLE, plus ERR.

- `rx` comes from outside the chip, so it isn't synchronized to `clk`. It first goes through **two flip-flops**. The first one can go metastable, and the second gives it a full clock period to settle before the logic uses the value.
- When the line drops low, the receiver waits **half a bit** to reach the middle of the start bit and checks it's still low. If it isn't, it was a glitch and is ignored.
- After that, it samples once every `CLKS_PER_BIT` clocks, so each data bit is read at its middle, where the signal is most stable.
- If the stop bit is 1, the byte goes out on `rx_data` with a one-clock `rx_valid` pulse. If the stop bit is 0, that's a framing error: the byte is dropped, and the receiver waits in ERR until the line goes high again.

## Files

- `rtl/uart_tx.v`, `rtl/uart_rx.v`: the design
- `tb/tb_uart.v`: testbench
- `sim/run.do`: ModelSim script

## How I tested it

The TX output is wired straight into an RX (a loopback), and a separate monitor in the testbench also decodes the TX line on its own, sampling the middle of each bit. So the transmitter is checked independently, not only through my own receiver.

- directed bytes `0x00`, `0xFF`, `0x55`, `0xA5`, then 20 random bytes
- every frame: start bit 0, data least significant bit first, stop bit 1
- `tx_start` pulsed in the middle of a frame is ignored
- `rx_valid` is never high for more than one clock
- the number of bytes received equals the number sent

A second receiver is driven directly by the testbench, with edges deliberately not lined up with the clock, to test:
- a normal byte
- a short glitch on the line (ignored)
- a frame with a bad stop bit (dropped)
- a good byte straight after the error (the receiver recovers)

```
Ran 4883 checks, 25 bytes via loopback
ALL TESTS PASSED
```

It also passes with `CLKS_PER_BIT` set to 8, 10 and 33.

To run: `cd sim` then `vsim -do run.do`

![waveform](docs/waveform.png)
