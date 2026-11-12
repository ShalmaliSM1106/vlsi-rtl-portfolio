# Instruction Set and Pipeline: `pipelined_cpu`

16-bit RISC-style CPU, 8 general registers (R0-R7), 16-bit data, 4-stage pipeline.

## Architectural state

| Item | Description |
|---|---|
| Registers | R0-R7, 16 bits each. **R0 is hardwired to 0**: writes are ignored, reads return 0. |
| PC | 16 bits, counts instructions (word addressed). Reset value 0. |
| Instruction memory | 256 x 16-bit words, loaded with `$readmemh(PROGRAM, imem)`. Unused words are `0000` (NOP). |
| Data memory | 256 x 16-bit words, word addressed. Address = low 8 bits of the ALU result. |
| Reset | Synchronous, active-high `rst`. |

## Instruction formats

```
R-type : [15:12] opcode | [11:9] rd  | [8:6] rs1 | [5:3] rs2 | [2:0] unused
I-type : [15:12] opcode | [11:9] rd  | [8:6] rs1 | [5:0] imm6        (ADDI, LW)
S-type : [15:12] opcode | [11:9] rt  | [8:6] rs1 | [5:0] imm6        (SW, BEQ)
J-type : [15:12] opcode | [11:0] address                             (JMP)
```

`imm6` is a signed 6-bit two's-complement value, range -32 to +31, sign-extended to 16 bits.

In S-type, the field `[11:9]` is a *source* register (the store data for SW, the second compare operand for BEQ), not a destination.

## Instruction set

| Mnemonic | Opcode | Format | Operation |
|---|---|---|---|
| NOP | `0x0` | - | no operation (`0x0000`) |
| ADD rd,rs1,rs2 | `0x1` | R | `rd = rs1 + rs2` |
| SUB rd,rs1,rs2 | `0x2` | R | `rd = rs1 - rs2` |
| AND rd,rs1,rs2 | `0x3` | R | `rd = rs1 & rs2` |
| OR rd,rs1,rs2 | `0x4` | R | `rd = rs1 \| rs2` |
| XOR rd,rs1,rs2 | `0x5` | R | `rd = rs1 ^ rs2` |
| ADDI rd,rs1,imm | `0x6` | I | `rd = rs1 + sext(imm6)` |
| LW rd,imm(rs1) | `0x7` | I | `rd = dmem[rs1 + sext(imm6)]` |
| SW rt,imm(rs1) | `0x8` | S | `dmem[rs1 + sext(imm6)] = rt` |
| BEQ ra,rb,imm | `0x9` | S | `if (R[11:9] == R[8:6]) PC = (address of BEQ) + 1 + sext(imm6)` |
| JMP addr | `0xA` | J | `PC = addr` (12-bit absolute; imem has 256 words) |
| HALT | `0xF` | - | stop fetching; `halted` goes high when HALT completes WB |

Unknown opcodes behave as NOP.

Encoding examples: `ADDI R2,R0,10` = `0x640A`; `ADD R1,R1,R2` = `0x1250`; `BEQ R2,R0,+1` = `0x9401`; `JMP 1` = `0xA001`; `HALT` = `0xF000`.

## Pipeline

| Stage | Work |
|---|---|
| IF | Read `imem[PC]`, compute PC + 1. |
| ID | Decode. Read registers (with write-through from WB). Detect data hazards. |
| EX | ALU. Data-memory read (LW) or write (SW). Decide BEQ/JMP. |
| WB | Write the result to the register file. |

Pipeline registers: IF/ID, ID/EX, EX/WB. Each carries a `valid` bit so bubbles and flushed instructions are not counted as retired.

## Hazard handling (no forwarding)

| Hazard | Detection | Action |
|---|---|---|
| Data (ID needs a value that the instruction in EX will write) | ID source register (that the instruction really uses) equals EX destination, EX writes a register and its `rd != R0` | **Stall 1 cycle**: hold PC and IF/ID, insert a bubble into ID/EX. After the stall the producer is in WB and the value arrives through write-through. |
| WB (producer is in WB while consumer is in ID) | `wb_we && exwb_rd == source` | The register read returns the WB value directly. No stall. |
| Control (BEQ taken, or JMP) | Decided in EX | Load PC with the target. Flush IF/ID and ID/EX (replace with NOPs). **2-cycle penalty.** A not-taken BEQ costs nothing. |
| HALT | HALT reaches EX | Stop fetching, flush younger instructions. Older instructions finish normally. `halted` rises when HALT is in WB. |

Dependency distance 1 costs 1 stall cycle. Distance 2 or more costs none. A load followed immediately by a use costs the same single stall, because the loaded value is available at the end of EX.

## Test programs (`prog1.hex` ... `prog4.hex`)

| File | Purpose | Expected result | Cycles | Instructions |
|---|---|---|---|---|
| prog1 | Loop adding 10..1 | R1 = 55 | printed by TB | 41 |
| prog2 | Back-to-back dependencies, distance-2 bypass | R1=12, R4=10, R6=20, R7=6 | 15 | 10 |
| prog3 | Not-taken BEQ, taken BEQ, JMP, flush | R3=3, R6=7, R4=R5=R7=0 | 15 | 8 |
| prog4 | AND/OR/XOR, SW/LW, load-use, R0 write ignored | R1=14, R2=8, R3=8, R4=14, R5=6, R6=8, R7=22, R0=0 | printed by TB | 13 |

Cycle counts are measured from reset release until HALT completes WB. A hazard-free program of N instructions takes N + 3 cycles. `program.hex` is a copy of `prog1.hex` (the default `PROGRAM`).
