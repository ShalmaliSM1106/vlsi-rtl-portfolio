# vlsi-rtl-portfolio
RTL design portfolio in Verilog | Simulated in ModelSim | VLSI &amp; SoC concepts

# VLSI & RTL Design Portfolio

![Language](https://img.shields.io/badge/HDL-Verilog-blue)
![Simulator](https://img.shields.io/badge/Simulator-ModelSim-9cf)
![Tools](https://img.shields.io/badge/Tools-Xilinx%20Vivado%20%7C%20Cadence%20Virtuoso-orange)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

A portfolio of RTL designs and VLSI projects implemented in Verilog and simulated in ModelSim. Projects are ordered by complexity — from foundational combinational logic to a pipelined CPU architecture. Each project includes RTL source, exhaustive testbenches, simulation waveforms, and synthesis reports where applicable.

---

## Tools & Environment

| Tool | Purpose |
|------|---------|
| ModelSim | RTL simulation and functional verification |
| Xilinx Vivado | Synthesis, area/power/timing analysis |
| Cadence Virtuoso (90nm) | Schematic, layout, Spectre simulation |
| Verilog (IEEE 1364-2001) | HDL |

---

## Project Index

| # | Project | Difficulty | Status |
|---|---------|-----------|--------|
| 01 | [Parameterized ALU](#01-parameterized-alu) | 
| 02 | [Universal Shift Register](#02-universal-shift-register) |
| 03 | [UART Transmitter + Receiver](#03-uart-transmitter--receiver) |
| 04 | [Synchronous FIFO](#04-synchronous-fifo-with-status-flags) |
| 05 | [SPI Master Controller](#05-spi-master-controller) |
| 06 | [FIR Filter](#06-8-tap-pipelined-fir-filter) |
| 07 | [Pipelined MIPS CPU](#07-16-bit-pipelined-mips-cpu) |
| 08 | [AXI4-Lite Slave Interface](#08-axi4-lite-slave-interface) |

---

## Project Details

### 01. Parameterized ALU
A fully parameterized N-bit ALU (default 4-bit, scalable to any width) supporting 8 operations with full flag outputs.

---

### 02. Universal Shift Register
An 8-bit universal shift register supporting all 4 modes — serial-in/serial-out, parallel load, shift left, shift right — with synchronous reset and enable.

---

### 03. UART Transmitter + Receiver
UART communication module with configurable baud rate, 8N1 format. Loopback testbench verifies TX→RX data integrity end to end.

---

### 04. Synchronous FIFO with Status Flags
Parameterized synchronous FIFO with full, empty, and almost-full flags. Testbench verifies overflow, underflow, and boundary conditions.

---

### 05. SPI Master Controller
SPI master supporting all 4 modes (CPOL/CPHA combinations) with a configurable clock divider. Testbench simulates a responding slave device.

---

### 06. 8-Tap Pipelined FIR Filter
Direct Form I FIR filter with parameterized coefficients, fully pipelined for throughput. Testbench applies a sine wave and verifies frequency attenuation.

---

### 07. 16-bit Pipelined MIPS CPU
4-stage pipelined CPU (Fetch → Decode → Execute → Writeback) supporting 8 instructions: ADD, SUB, AND, OR, LW, SW, BEQ, J. Includes hazard detection unit. Testbench runs a small assembly program end to end.

---

### 08. AXI4-Lite Slave Interface
A simple register file accessible over AXI4-Lite. Implements read/write transactions with BRESP/RRESP signaling — demonstrates industry-standard SoC bus protocol.

---

## Repository Structure

```
vlsi-rtl-portfolio/
├── 01_ALU/
│   ├── rtl/
│   ├── tb/
│   ├── top/
│   ├── sim_results/
│   └── README.md
├── 02_Shift_Register/
├── 03_UART/
├── 04_FIFO/
├── 05_SPI/
├── 06_FIR_Filter/
├── 07_MIPS_CPU/
├── 08_AXI4_Lite/
└── README.md
```

---

## About

**Shalmali Mankikar**  
B.E. Electronics and Communication Engineering  
Dayananda Sagar College of Engineering, Bangalore  
📧 shalmalimankikar1106@gmail.com
