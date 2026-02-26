# Nibble — 4-bit CPU for TinyTapeout IHP

A minimal 4-bit accumulator CPU designed for fabrication on IHP SG13G2 130nm through [TinyTapeout](https://tinytapeout.com). Fits in a single tile (194 standard cells, 15% utilization). Fully verified at both RTL and gate-level.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Block Diagram](#block-diagram)
- [Detailed Schematic](#detailed-schematic)
  - [Register File](#1-register-file-20-flip-flops)
  - [Instruction Decoder](#2-instruction-decoder)
  - [ALU](#3-alu-arithmetic-logic-unit)
  - [Branch Logic](#4-branch-logic)
  - [Fetch-Execute FSM](#5-fetch-execute-fsm)
- [Instruction Set](#instruction-set)
- [TinyTapeout Pin Mapping](#tinytapeout-pin-mapping)
- [Example Programs](#example-programs)
- [Verilog Playground (Zero Install)](#verilog-playground-zero-install)
- [TinyTapeout Web Design Flow](#tinytapeout-web-design-flow)
- [Tool Installation](#tool-installation)
  - [macOS](#macos)
  - [Windows](#windows-wsl2)
  - [Linux (Ubuntu/Debian)](#linux-ubuntudebian)
  - [Code Editor (VS Code)](#code-editor-vs-code)
  - [Docker (All Platforms)](#docker-all-platforms)
  - [Which Setup Do I Need?](#which-setup-do-i-need)
  - [Post-Install Verification](#post-install-verification)
- [Quick Start](#quick-start)
- [Workshop Guide](#workshop-guide)
- [Synthesis Results](#synthesis-results)
- [Testing on the TinyTapeout PCB](#testing-on-the-tinytapeout-pcb)
  - [Board Overview](#board-overview)
  - [How It Works: RP2040 = Program Memory](#how-it-works-rp2040--program-memory)
  - [RP2040 Firmware (MicroPython)](#rp2040-firmware-micropython)
  - [RP2040 Firmware (C / Arduino)](#rp2040-firmware-c--arduino)
  - [Step-by-Step Testing](#step-by-step-testing)
  - [What You'll See](#what-youll-see)
  - [Demo Programs for the PCB](#demo-programs-for-the-pcb)
  - [Using DIP Switches as Input](#using-dip-switches-as-input)
  - [Clock Speed Tips](#clock-speed-tips)
  - [Troubleshooting](#troubleshooting)

---

## Architecture Overview

Nibble is a **Harvard-architecture** accumulator machine:

- **Data width:** 4 bits
- **Instruction width:** 8 bits (`[7:4]` = opcode, `[3:0]` = immediate/address)
- **Registers:** Accumulator (A), Program Counter (PC), Instruction Register (IR)
- **Flags:** Carry (C), Zero (Z)
- **Pipeline:** 2-cycle fetch-execute (1 instruction every 2 clock cycles)
- **Memory:** External program memory via input pins (no internal ROM)
- **I/O:** 4-bit input port, accumulator always visible on output

---

## Block Diagram

```
                        TinyTapeout IHP Chip
    ┌──────────────────────────────────────────────────────┐
    │                                                      │
    │  ui_in[7:0] ──────────┐                              │
    │  (instruction)        │                              │
    │                   ┌───▼───┐    ┌────────────┐        │
    │                   │  IR   │───►│  OPCODE    │        │
    │                   │ 8-bit │    │  DECODER   │        │
    │                   └───────┘    └─────┬──────┘        │
    │                                      │ control       │
    │                       ┌──────────────┼──────────┐    │
    │                       │              │          │    │
    │                   ┌───▼───┐    ┌─────▼────┐    │    │
    │  uio[7:4] ──────►│  MUX  │───►│   ALU    │    │    │
    │  (input port)     │ 4-bit │    │  4-bit   │    │    │
    │                   └───────┘    │ +,-,&,|  │    │    │
    │                                │ ^,~,<<,>>│    │    │
    │                   ┌────────┐   └──┬───┬───┘    │    │
    │                   │  ACC   │◄─────┘   │        │    │
    │                   │ 4-bit  │──────────┼──►uo_out[3:0]
    │                   └────────┘     C,Z  │        │    │
    │                                  flags│        │    │
    │                   ┌────────┐   ┌──▼───▼──┐     │    │
    │                   │   PC   │◄──┤ BRANCH  │     │    │
    │                   │ 4-bit  │   │  LOGIC  │     │    │
    │                   └───┬────┘   └─────────┘     │    │
    │                       │                        │    │
    │                       └──────────────────────►uio[3:0]
    │                         (address bus)          │    │
    │                                                │    │
    │                   ┌────────┐                   │    │
    │            clk───►│ FETCH/ │───────────────────┘    │
    │          rst_n───►│EXECUTE │   uo_out[7] = phase    │
    │                   │  FSM   │   uo_out[6] = halted   │
    │                   └────────┘   uo_out[5] = zero     │
    │                                uo_out[4] = carry    │
    └──────────────────────────────────────────────────────┘
```

---

## Detailed Schematic

Below is the gate-level breakdown of each CPU subsystem. After synthesis to IHP SG13G2, the CPU uses **194 standard cells** (20 flip-flops + 174 combinational gates).

### 1. Register File (20 Flip-Flops)

All state is held in D flip-flops with async active-low reset (`sg13g2_dfrbpq_1`):

```
                    ┌──────────────────────────────────────────────┐
                    │            REGISTER FILE (20 DFFs)           │
                    │                                              │
    clk ───────────►│  ACC[3:0]    4 x DFF ──► uo_out[3:0]       │
    rst_n ─────────►│  PC[3:0]     4 x DFF ──► uio_out[3:0]      │
                    │  IR[7:0]     8 x DFF     (internal)         │
                    │  carry       1 x DFF ──► uo_out[4]          │
                    │  zero        1 x DFF ──► uo_out[5]          │
                    │  halted      1 x DFF ──► uo_out[6]          │
                    │  phase       1 x DFF ──► uo_out[7]          │
                    │                                              │
                    │  Total: 4+4+8+1+1+1+1 = 20 flip-flops      │
                    └──────────────────────────────────────────────┘

    Each DFF (sg13g2_dfrbpq_1):
    ┌─────────┐
    │  D    Q ├──► output
    │         │
    │ CLK    ─┤◄── clk
    │ RST_B ─┤◄── rst_n (active low: Q=0 when RST_B=0)
    └─────────┘
```

### 2. Instruction Decoder

The opcode decoder splits the 8-bit instruction register and generates control signals:

```
    IR[7:0]
    ┌────────────────────────┐
    │ 7  6  5  4 │ 3  2  1  0│
    │   OPCODE   │IMMEDIATE  │
    └──────┬─────┴─────┬─────┘
           │           │
           ▼           ▼
    ┌─────────────┐   imm[3:0] ──► ALU operand B
    │   4-to-16   │              ──► Branch target
    │   DECODER   │              ──► LDI value
    │             │
    │ (AND/NOR/   │
    │  NAND gates)│
    └──────┬──────┘
           │
           ▼ 16 control lines (active for each opcode)
    ┌──────────────────────────────────────────────┐
    │ is_NOP  is_LDI  is_ADD  is_SUB              │
    │ is_AND  is_OR   is_XOR  is_NOT              │
    │ is_SHL  is_SHR  is_JMP  is_JZ               │
    │ is_JC   is_JNZ  is_IN   is_HLT              │
    └──────────────────────────────────────────────┘

    Example decode for opcode = 4'b0010 (ADD):
    ┌─────┐
    │ NOT ├◄── IR[7]  ──► IR[7]' = 1
    └──┬──┘
    ┌──▼──────────────────────┐
    │       AND4              │
    │  IR[7]' & IR[6]'       │──► is_ADD = 1
    │  & IR[5] & IR[4]'      │
    └─────────────────────────┘
```

### 3. ALU (Arithmetic Logic Unit)

The ALU is **purely combinational** — it computes the result every cycle, but the result is only latched into ACC during the EXECUTE phase.

```
    ┌───────────────────────────────────────────────────┐
    │                   4-BIT ALU                       │
    │                                                   │
    │   ACC[3:0] ──►┌──────┐                           │
    │               │ 4-BIT│──► sum[3:0]  ──┐          │
    │   imm[3:0] ──►│ ADDER│──► cout      ──┤          │
    │               └──────┘                │          │
    │                                       │          │
    │   ACC[3:0] ──►┌──────┐               ┌▼────────┐│
    │               │ 4-BIT│──► diff[3:0]──►│         ││
    │   imm[3:0] ──►│SUBTR │──► bout     ──►│  RESULT ││
    │               └──────┘               │   MUX   ││──► next_acc[3:0]
    │                                      │         ││──► next_carry
    │   ACC[3:0] ──►─── AND ──► and[3:0]──►│ (16:1)  ││──► next_zero
    │   imm[3:0] ──►─── AND               │         ││
    │                                      │ select: ││
    │   ACC[3:0] ──►─── OR  ──► or[3:0] ──►│ opcode  ││
    │   imm[3:0] ──►─── OR                │         ││
    │                                      │         ││
    │   ACC[3:0] ──►─── XOR ──► xor[3:0]──►│         ││
    │   imm[3:0] ──►─── XOR               │         ││
    │                                      │         ││
    │   ACC[3:0] ──►─── NOT ──► not[3:0]──►│         ││
    │                                      │         ││
    │   ACC[3:0] ──►─── SHL ──► shl[3:0]──►│         ││
    │              (shift left, MSB→carry) │         ││
    │                                      │         ││
    │   ACC[3:0] ──►─── SHR ──► shr[3:0]──►│         ││
    │              (shift right, LSB→carry)│         ││
    │                                      │         ││
    │   port_in[3:0] ─────────► in[3:0] ──►│         ││
    │                                      │         ││
    │   imm[3:0] ─────────────► ldi[3:0]──►│         ││
    │                                      └─────────┘│
    │                                                   │
    │   Zero detect: NOR(result[3], result[2],         │
    │                    result[1], result[0]) ──► Z   │
    └───────────────────────────────────────────────────┘

    4-bit Adder Detail (ripple carry):
    ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
    │  FA  │──│  FA  │──│  FA  │──│  FA  │──► Cout
    │ [0]  │  │ [1]  │  │ [2]  │  │ [3]  │
    └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘
       ▼         ▼         ▼         ▼
    sum[0]    sum[1]    sum[2]    sum[3]

    Full Adder (FA) gate-level:
         A ──┬──►XOR──┬──►XOR──► Sum
         B ──┘        │    ▲
                      │   Cin
         A ──┬──►AND──┘
         B ──┘        ├──►OR ──► Cout
        Cin──┬──►AND──┘
    (A^B)────┘
```

### 4. Branch Logic

Determines whether to load PC from `imm[3:0]` (branch taken) or `PC+1` (sequential):

```
    ┌───────────────────────────────────────────┐
    │             BRANCH LOGIC                  │
    │                                           │
    │   is_JMP ────────────────────►OR──┐       │
    │                                   │       │
    │   is_JZ  ──►AND──┐              │       │
    │   zero ────►AND──┴──►OR─────────►OR──┐   │
    │                                      │   │
    │   is_JC  ──►AND──┐                  │   │
    │   carry ───►AND──┴──►OR─────────────►OR──┤
    │                                          │
    │   is_JNZ ──►AND──┐                      │
    │   ~zero ───►AND──┴──►OR─────────────────┤
    │                                          │
    │                              take_branch │
    │                                          ▼
    │   ┌─────────────┐          ┌───────────────┐
    │   │   PC + 1    │──────────►│     MUX       │──► next_pc[3:0]
    │   │ (4-bit incr)│          │  0: PC+1      │
    │   └─────────────┘          │  1: imm[3:0]  │
    │                            │  sel: branch  │
    │   imm[3:0] ────────────────►│               │
    │                            └───────────────┘
    └───────────────────────────────────────────┘
```

### 5. Fetch-Execute FSM

A single flip-flop (`phase`) controls the 2-cycle pipeline:

```
    ┌──────────────────────────────────────────────────────┐
    │              FETCH-EXECUTE STATE MACHINE              │
    │                                                      │
    │   reset ──► phase = 0 (FETCH)                        │
    │                                                      │
    │   ┌─────────┐         ┌─────────────┐               │
    │   │  FETCH  │────────►│  EXECUTE    │               │
    │   │ phase=0 │         │  phase=1    │               │
    │   │         │◄────────│             │               │
    │   └─────────┘         └─────────────┘               │
    │                                                      │
    │   FETCH (phase=0):             EXECUTE (phase=1):    │
    │    IR <= ui_in[7:0]            ACC   <= next_acc     │
    │    phase <= 1                  PC    <= next_pc      │
    │                                carry <= next_carry   │
    │                                zero  <= next_zero    │
    │                                halted<= next_halted  │
    │                                phase <= 0            │
    │                                                      │
    │   HALT check: if halted=1, FSM stops                │
    │   (clock keeps running, registers frozen)            │
    └──────────────────────────────────────────────────────┘

    Timing Diagram:
    ─────────────────────────────────────────────────────────
    clk     ╱╲__╱╲__╱╲__╱╲__╱╲__╱╲__╱╲__╱╲__╱╲__
    phase   ___0____1____0____1____0____1____0____
    action  FETCH EXEC  FETCH EXEC  FETCH EXEC
             instr0      instr1      instr2
    PC out   0          1          2
    ACC      ----  res0  ---- res1  ---- res2
    ─────────────────────────────────────────────────────────
```

### Complete Gate-Level Cell Usage (IHP SG13G2)

```
    Cell Type           Count    Function
    ─────────────────────────────────────────────
    sg13g2_dfrbpq_1       20    D flip-flop (async reset)
    sg13g2_nor2_1         17    2-input NOR
    sg13g2_o21ai_1        15    OR-AND-INV: ~((A|B)&C)
    sg13g2_nand2_1        15    2-input NAND
    sg13g2_a22oi_1        15    AND-OR-INV: ~((A&B)|(C&D))
    sg13g2_nand3_1        14    3-input NAND
    sg13g2_inv_1          14    Inverter
    sg13g2_and2_1         10    2-input AND
    sg13g2_a21oi_1        10    AND-OR-INV: ~((A&B)|C)
    sg13g2_nor4_1          9    4-input NOR
    sg13g2_nand2b_1        9    NAND with inverted input
    sg13g2_mux2_1          8    2:1 Multiplexer
    sg13g2_xnor2_1         6    2-input XNOR
    sg13g2_nor3_1          6    3-input NOR
    sg13g2_nand4_1         6    4-input NAND
    sg13g2_a221oi_1        5    AND-AND-OR-INV
    sg13g2_xor2_1          4    2-input XOR
    sg13g2_nor2b_1         4    NOR with inverted input
    sg13g2_nand3b_1        3    NAND with inverted input
    sg13g2_or2_1           2    2-input OR
    sg13g2_and4_1          1    4-input AND
    sg13g2_and3_1          1    3-input AND
    ─────────────────────────────────────────────
    TOTAL                194    cells
    Chip Area        2,677 um²  (15% of 1x1 tile)
    Sequential          20      flip-flops (37% of area)
    Combinational      174      logic gates
```

---

## Instruction Set

```
Opcode  Hex    Mnemonic    Operation                    Flags
──────  ───    ────────    ─────────                    ─────
0000    0x0    NOP         No operation                 -
0001    0x1    LDI imm     A = imm                      Z
0010    0x2    ADD imm     A = A + imm                  C, Z
0011    0x3    SUB imm     A = A - imm                  C, Z
0100    0x4    AND imm     A = A & imm                  Z
0101    0x5    OR  imm     A = A | imm                  Z
0110    0x6    XOR imm     A = A ^ imm                  Z
0111    0x7    NOT         A = ~A                       Z
1000    0x8    SHL         {C,A} = {A[3], A<<1}         C, Z
1001    0x9    SHR         {A,C} = {A>>1, A[0]}         C, Z
1010    0xA    JMP addr    PC = addr                    -
1011    0xB    JZ  addr    if Z: PC = addr              -
1100    0xC    JC  addr    if C: PC = addr              -
1101    0xD    JNZ addr    if !Z: PC = addr             -
1110    0xE    IN          A = input_port               Z
1111    0xF    HLT         Halt CPU                     -
```

**Instruction encoding:** `[7:4]` = opcode, `[3:0]` = 4-bit immediate or jump address.

**Flags:**
- **C (Carry):** Set on ADD overflow, SUB borrow, SHL/SHR bit shifted out
- **Z (Zero):** Set when result is `4'b0000`

---

## TinyTapeout Pin Mapping

```
    ┌──────────────────────────────────────────────────┐
    │              TinyTapeout IHP Tile                 │
    │                                                  │
    │  ACTIVE-LOW ACTIVE-  ACTIVE-                     │
    │   RESET     HIGH     HIGH                        │
    │  ┌─────┐  ┌─────┐  ┌─────┐                      │
    │  │rst_n│  │ clk │  │ ena │                       │
    │  └──┬──┘  └──┬──┘  └──┬──┘                       │
    │     ▼        ▼        ▼                          │
    ├──────────────────────────────────────────────────┤
    │           ACTIVE ACTIVE                          │
    │           ACTIVE ACTIVE                          │
    │   ACTIVE  ┌─────────┐  ACTIVE  ┌─────────┐      │
    │   ACTIVE  │ ui_in   │  ACTIVE  │ uo_out  │      │
    │           │ [7:0]   │          │ [7:0]   │      │
    │           └─────────┘          └─────────┘      │
    │                                                  │
    │           ┌─────────┐                            │
    │           │  uio    │                            │
    │           │ [7:0]   │                            │
    │           └─────────┘                            │
    └──────────────────────────────────────────────────┘
```

| Pin | Dir | Signal | Connect to |
|-----|-----|--------|------------|
| `ui_in[7]` | in | Instruction bit 7 (opcode MSB) | RP2040 / EEPROM data |
| `ui_in[6]` | in | Instruction bit 6 | " |
| `ui_in[5]` | in | Instruction bit 5 | " |
| `ui_in[4]` | in | Instruction bit 4 (opcode LSB) | " |
| `ui_in[3]` | in | Instruction bit 3 (imm MSB) | " |
| `ui_in[2]` | in | Instruction bit 2 | " |
| `ui_in[1]` | in | Instruction bit 1 | " |
| `ui_in[0]` | in | Instruction bit 0 (imm LSB) | " |
| `uo_out[3:0]` | out | **Accumulator** | LEDs (see your result!) |
| `uo_out[4]` | out | Carry flag | LED |
| `uo_out[5]` | out | Zero flag | LED |
| `uo_out[6]` | out | Halted | LED |
| `uo_out[7]` | out | Phase (0=fetch, 1=exec) | LED / scope |
| `uio[3:0]` | out | **Program Counter** | RP2040 / EEPROM address |
| `uio[7:4]` | in | Input port (for IN) | DIP switches / RP2040 |

---

## Example Programs

### Counter (counts 0-15 on LEDs, then halts)

```
Addr  Hex   Binary      Assembly    Description
----  ----  ----------  ---------   -------------------------
0x0   0x10  0001 0000   LDI 0       Load 0 into accumulator
0x1   0x21  0010 0001   ADD 1       Add 1
0x2   0xD1  1101 0001   JNZ 1       Loop back if not zero
0x3   0xF0  1111 0000   HLT         Halt (A wrapped to 0)
```

### Fibonacci (0, 1, 1, 2, 3, 5, 8, 13)

```
Addr  Hex   Assembly    ACC after
----  ----  ---------   ---------
0x0   0x10  LDI 0       0
0x1   0x21  ADD 1       1
0x2   0x20  ADD 0       1
0x3   0x21  ADD 1       2
0x4   0x21  ADD 1       3
0x5   0x22  ADD 2       5
0x6   0x23  ADD 3       8
0x7   0x25  ADD 5       13
0x8   0xF0  HLT         (halted)
```

### Shift & Carry test

```
Addr  Hex   Assembly    ACC   C  Z
----  ----  ---------   ----  -  -
0x0   0x11  LDI 1       0001  0  0
0x1   0x80  SHL         0010  0  0
0x2   0x80  SHL         0100  0  0
0x3   0x80  SHL         1000  0  0
0x4   0x80  SHL         0000  1  1   ← carry out!
0x5   0xF0  HLT
```

### Conditional branching

```
Addr  Hex   Assembly    Description
----  ----  ---------   ---------------------------
0x0   0x10  LDI 0       A=0, Z=1
0x1   0xB4  JZ 4        Jump to 0x4 (Z is set)
0x2   0x1F  LDI 15      (skipped)
0x3   0xF0  HLT         (skipped)
0x4   0x17  LDI 7       A=7, Z=0
0x5   0x29  ADD 9       A=0 (overflow), C=1
0x6   0xC9  JC 9        Jump to 0x9 (C is set)
```

---

## Verilog Playground (Zero Install)

Before installing anything locally, you can write and simulate Verilog **right in your browser**. These tools are perfect for warming up or if you're on a locked-down machine:

| Tool | URL | What it does | Best for |
|------|-----|-------------|----------|
| **EDA Playground** | [edaplayground.com](https://www.edaplayground.com/) | Write Verilog + testbench, simulate with Icarus Verilog, view waveforms | General simulation — our primary zero-install tool |
| **HDLBits** | [hdlbits.01xz.net](https://hdlbits.01xz.net/) | 170+ interactive Verilog exercises with auto-grading | Learning Verilog step-by-step |
| **DigitalJS Online** | [digitaljs.tilk.eu](https://digitaljs.tilk.eu/) | Paste Verilog, see synthesized gate-level schematic, simulate interactively | Visualizing how code becomes gates |
| **Wokwi** | [wokwi.com](https://wokwi.com/) | Drag-and-drop logic gate editor, simulate in browser | Absolute beginners (no code needed) |

### Quick Start: EDA Playground

1. Go to [edaplayground.com](https://www.edaplayground.com/) and sign up (free, 30 seconds)
2. Set language to **Verilog** and simulator to **Icarus Verilog 12.0**
3. Check **"Open EPWave after run"** for waveform viewing
4. Paste this in the **Design** tab (left panel):

```verilog
module counter (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] count
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            count <= 4'b0000;
        else
            count <= count + 1;
endmodule
```

5. Paste this in the **Testbench** tab (right panel):

```verilog
module tb;
    reg clk = 0, rst_n = 0;
    wire [3:0] count;
    counter uut (.clk(clk), .rst_n(rst_n), .count(count));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
        #12 rst_n = 1;
        #200 $finish;
    end
endmodule
```

6. Click **Run** — you'll see `count` going 0, 1, 2, 3... in the waveform viewer!

### Quick Start: DigitalJS (See Your Code as Gates)

1. Go to [digitaljs.tilk.eu](https://digitaljs.tilk.eu/)
2. Paste any Verilog (try a small ALU or adder)
3. Click **Synthesize** — see the actual gate-level schematic
4. Uses **Yosys compiled to WebAssembly** — real synthesis running in your browser!

### Recommended HDLBits Warm-Up Path

These 8 exercises cover every building block in our CPU:

1. [Wire](https://hdlbits.01xz.net/wiki/Wire) — the simplest module
2. [NOT gate](https://hdlbits.01xz.net/wiki/Notgate)
3. [AND gate](https://hdlbits.01xz.net/wiki/Andgate)
4. [4-bit MUX](https://hdlbits.01xz.net/wiki/Mux2to1v)
5. [Half adder](https://hdlbits.01xz.net/wiki/Hadd)
6. [Full adder](https://hdlbits.01xz.net/wiki/Fadd)
7. [D flip-flop](https://hdlbits.01xz.net/wiki/Dff)
8. [4-bit counter](https://hdlbits.01xz.net/wiki/Count15)

---

## TinyTapeout Web Design Flow

TinyTapeout offers **two ways** to design your chip — both start in the browser:

### Option A: Wokwi (Visual, No Code)

- Drag-and-drop logic gates in the browser
- Simulate your circuit visually
- Auto-generates netlist for tapeout
- Great for absolute beginners!
- Guide: [tinytapeout.com/digital_design/wokwi](https://tinytapeout.com/digital_design/wokwi/)

### Option B: Verilog (Code, Full Control)

- Fork the [TinyTapeout IHP template](https://github.com/TinyTapeout/ttihp-verilog-template) on GitHub
- Write Verilog — even using GitHub's built-in web editor (no local tools needed!)
- Push to GitHub → GitHub Actions automatically runs OpenLane (synthesis → place & route → GDS)
- Guide: [tinytapeout.com/digital_design](https://tinytapeout.com/digital_design/)

> **Our workshop uses Option B** (Verilog). But if a participant has never written code before, start them on Option A with Wokwi — they can build a simple gate circuit and see it taped out!

---

## Tool Installation

### macOS

```bash
# 1. Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install simulation tools
brew install icarus-verilog        # Verilog simulator (iverilog)
brew install --cask gtkwave        # Waveform viewer

# 3. Install synthesis tool
brew install yosys                 # RTL synthesis

# 4. Install IHP PDK (standard cell library)
cd ~
git clone --depth 1 https://github.com/IHP-GmbH/IHP-Open-PDK.git

# 5. Verify installation
iverilog -V | head -1              # should print version
yosys --version                    # should print version
ls ~/IHP-Open-PDK/ihp-sg13g2/     # should list libs.ref, libs.tech, etc.

# 6. (Optional) Install Python for cocotb testing
brew install python3
pip3 install cocotb

# 7. (Optional) Docker for full OpenLane PnR flow
# Install Docker Desktop from https://www.docker.com/products/docker-desktop/
```

### Windows (WSL2)

Windows users should use WSL2 (Windows Subsystem for Linux). All tools run natively in WSL2.

```powershell
# Step 1: Install WSL2 (run in PowerShell as Administrator)
wsl --install -d Ubuntu-22.04

# Step 2: Restart your computer, then open "Ubuntu" from Start menu
```

Then inside the WSL2 Ubuntu terminal, follow the Linux instructions below.

**Alternative: Without WSL2** (limited, simulation only)

```powershell
# Install via MSYS2 (https://www.msys2.org/)
# After installing MSYS2, open MSYS2 MINGW64 terminal:
pacman -S mingw-w64-x86_64-iverilog
pacman -S mingw-w64-x86_64-yosys

# Or use OSS CAD Suite (all-in-one):
# Download from https://github.com/YosysHQ/oss-cad-suite-build/releases
# Extract and add to PATH
```

### Linux (Ubuntu/Debian)

```bash
# 1. Install simulation tools
sudo apt update
sudo apt install -y iverilog gtkwave

# 2. Install synthesis tool
sudo apt install -y yosys

# If the packaged yosys is too old, install from source or use OSS CAD Suite:
# wget https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2024-02-01/oss-cad-suite-linux-x64-20240201.tgz
# tar xzf oss-cad-suite-linux-x64-*.tgz
# export PATH="$PWD/oss-cad-suite/bin:$PATH"

# 3. Install IHP PDK
cd ~
git clone --depth 1 https://github.com/IHP-GmbH/IHP-Open-PDK.git

# 4. Verify
iverilog -V | head -1
yosys --version
ls ~/IHP-Open-PDK/ihp-sg13g2/

# 5. (Optional) Docker for full OpenLane PnR flow
sudo apt install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
```

### Code Editor (VS Code)

A good editor makes writing Verilog much easier. VS Code with the Verilog extension gives you syntax highlighting, auto-complete, and live error checking.

**Install VS Code:**

Download from [code.visualstudio.com](https://code.visualstudio.com/) (macOS, Windows, Linux).

**Install the Verilog extension:**

```bash
code --install-extension mshr-h.VerilogHDL
```

**Configure linting** (uses iverilog as backend — must be installed first):

Open VS Code Settings (Ctrl+, or Cmd+,) and add:

```json
{
    "verilog.linting.linter": "iverilog",
    "verilog.linting.iverilog.arguments": "-g2012 -Wall"
}
```

Now VS Code shows errors **as you type** — red squiggles on syntax errors, warnings on unused signals. This catches bugs before you even run the simulator.

**Alternatives:** Sublime Text, Vim/Neovim (with verilog plugin), or just use [EDA Playground](https://www.edaplayground.com/) in the browser.

### Docker (All Platforms)

Docker gives you a **complete, pre-configured environment** for running the full OpenLane Place & Route flow. No manual tool installation needed — everything runs inside a container.

**Step 1: Install Docker**

| Platform | How to install |
|----------|---------------|
| **macOS** | Download [Docker Desktop](https://www.docker.com/products/docker-desktop/), install, and start it |
| **Windows** | Download [Docker Desktop](https://www.docker.com/products/docker-desktop/), install (enable WSL2 backend), and start it |
| **Linux** | `sudo apt install -y docker.io && sudo usermod -aG docker $USER` then log out and back in |

**Step 2: Verify Docker is running**

```bash
docker --version
docker run hello-world    # should print "Hello from Docker!"
```

**Step 3: Run the full OpenLane PnR flow**

```bash
# Pull the TinyTapeout IHP OpenLane image
docker pull ghcr.io/tinytapeout/openlane2:latest

# Clone the TinyTapeout IHP template
git clone https://github.com/TinyTapeout/ttihp-verilog-template.git
cd ttihp-verilog-template

# Copy your design files into the template
cp /path/to/Tinytapeout_4bitCPU/src/project.v src/
cp /path/to/Tinytapeout_4bitCPU/src/cpu_core.v src/
cp /path/to/Tinytapeout_4bitCPU/src/config.json src/
cp /path/to/Tinytapeout_4bitCPU/info.yaml .

# Run the full hardening flow (synthesis → place & route → GDS)
docker run --rm -v $(pwd):/work -w /work \
  ghcr.io/tinytapeout/openlane2:latest \
  python -m openlane --run-tag run1 src/config.json
```

The output GDS file (your physical layout ready for fabrication) will be in `runs/run1/final/gds/`.

### Which Setup Do I Need?

| Goal | What to install | Platform |
|------|----------------|----------|
| **Just simulate** (RTL testbench only) | Icarus Verilog + GTKWave | macOS, Linux, Windows |
| **Simulate + Synthesize** (see gate-level results) | + Yosys + IHP PDK | macOS, Linux, WSL2 |
| **Full PnR flow locally** (generate GDS layout) | + Docker + OpenLane | macOS, Linux, Windows |
| **Just submit to TinyTapeout** (let CI do the work) | Just git + GitHub account! | Any |

> **Recommended for workshop:** Install iverilog + yosys + IHP PDK natively for fast iteration. Use Docker or GitHub CI for the final PnR/GDS step.

### Post-Install Verification

Run these steps **one by one** after installation. Each step tests a specific tool — if one fails, you know exactly what's broken:

```bash
# ── Step 1: Check tools are installed ──
iverilog -V 2>&1 | head -1       # expect: "Icarus Verilog version 1x.x"
yosys --version                   # expect: "Yosys 0.xx"
ls ~/IHP-Open-PDK/ihp-sg13g2/    # expect: libs.ref  libs.tech  ...

# ── Step 2: Clone the project ──
git clone https://github.com/fidel-makatia/Tinytapeout_4bitCPU.git
cd Tinytapeout_4bitCPU

# ── Step 3: RTL simulation (tests iverilog) ──
make test
# ✅ expect: "RESULTS: 51 / 51 passed — ALL TESTS PASSED"

# ── Step 4: Synthesis (tests yosys + IHP PDK) ──
IHP_PDK=~/IHP-Open-PDK make synth
# ✅ expect: "Number of cells: 194"

# ── Step 5: Gate-level simulation (tests everything together) ──
IHP_PDK=~/IHP-Open-PDK make test_gl
# ✅ expect: "RESULTS: 51 / 51 passed — ALL TESTS PASSED"

# ── Step 6: Waveform viewer (tests GTKWave) ──
make wave
# ✅ expect: GTKWave window opens showing waveform signals
```

**Troubleshooting:**

| Step that fails | Problem | Fix |
|-----------------|---------|-----|
| Step 1: `iverilog: command not found` | iverilog not installed | macOS: `brew install icarus-verilog` / Linux: `sudo apt install iverilog` |
| Step 1: `yosys: command not found` | yosys not installed | macOS: `brew install yosys` / Linux: `sudo apt install yosys` |
| Step 1: `ls: No such file or directory` | IHP PDK not cloned | `cd ~ && git clone --depth 1 https://github.com/IHP-GmbH/IHP-Open-PDK.git` |
| Step 3: compile errors | Wrong iverilog version | Need iverilog with `-g2012` support (version 11+) |
| Step 4: `Can't open liberty file` | IHP_PDK path wrong | Check path: `ls $IHP_PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/` |
| Step 5: `Unknown module type` | Missing cell models | Make sure `test/sg13g2_functional.v` exists in the repo |
| Step 6: GTKWave doesn't open | GTKWave not installed | macOS: `brew install --cask gtkwave` / Linux: `sudo apt install gtkwave` |

---

## Quick Start

```bash
make test          # RTL simulation — 51/51 tests
make synth         # Synthesize to IHP SG13G2 (194 cells)
make test_gl       # Gate-level simulation — 51/51 tests
make wave          # View waveforms in GTKWave
make clean         # Remove generated files
```

Set `IHP_PDK` if your PDK is not at `~/IHP-Open-PDK`:
```bash
export IHP_PDK=/path/to/IHP-Open-PDK
```

---

## Workshop Guide

### Session 1: Understanding the CPU (30 min)

1. Read through this README — understand the architecture and instruction set
2. Study `src/cpu_core.v` — trace the fetch-execute FSM
3. Look at the block diagram and identify each component in the Verilog
4. Write a simple program by hand (e.g., load 5, add 3, halt)

### Session 2: Simulation & Verification (45 min)

1. Run `make test` and observe all 51 tests passing
2. Run `make wave` and open the VCD in GTKWave
3. Add signals: `clk`, `rst_n`, `phase`, `pc`, `acc`, `ir`, `carry`, `zero`
4. Trace through the counter program (Test 4) cycle by cycle
5. Challenge: write your own test program in `test/tb.v`

### Session 3: Synthesis to Real Silicon (45 min)

1. Run `make synth` — synthesize to IHP SG13G2 standard cells
2. Examine `outputs/synth_stats.txt` — count cells, check area
3. Run `make test_gl` — verify the gate-level netlist matches RTL
4. Open `outputs/synth_netlist.v` — find your flip-flops and gates
5. Discuss: what happens next? (OpenLane PnR → GDS → fabrication)

### Session 4: Tapeout Submission (30 min)

1. Fork the [TinyTapeout IHP Verilog template](https://github.com/TinyTapeout/ttihp-verilog-template)
2. Copy `src/project.v`, `src/cpu_core.v`, `src/config.json` into `src/`
3. Update `info.yaml` with your project details
4. Push to GitHub — CI automatically runs OpenLane and produces GDS
5. Submit at [app.tinytapeout.com](https://app.tinytapeout.com)

---

## Synthesis Results

| Metric | Value |
|--------|-------|
| Target PDK | IHP SG13G2 (130nm) |
| Total cells | 194 |
| Flip-flops | 20 |
| Combinational | 174 |
| Chip area | 2,677 um² |
| Tile size | 167 x 108 um (18,036 um²) |
| **Utilization** | **~15%** |
| RTL test | 51/51 PASS |
| Gate-level test | 51/51 PASS |

---

## Testing on the TinyTapeout PCB

Once your chip comes back from fabrication at IHP, it arrives mounted on a **TinyTapeout demo PCB**. This section explains exactly how to run your CPU on real silicon.

### Board Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  TinyTapeout Demo Board                     │
│                                                             │
│   ┌───────────┐              ┌──────────────┐              │
│   │           │   SPI bus    │              │              │
│   │  RP2040   │─────────────►│  YOUR CHIP   │              │
│   │  (MCU)    │              │  (ASIC)      │              │
│   │           │◄─────────────│              │              │
│   └─────┬─────┘              └──────┬───────┘              │
│         │                           │                       │
│   ┌─────▼─────┐              ┌──────▼───────┐              │
│   │  USB-C    │              │   PMODs      │              │
│   │ (power +  │              │  (I/O pins)  │              │
│   │  program) │              │              │              │
│   └───────────┘              └──────────────┘              │
│                                                             │
│   [DIP switches]       [7-seg display]       [LED bar]     │
└─────────────────────────────────────────────────────────────┘
```

The board has:
- **RP2040** microcontroller — drives inputs, reads outputs, generates clock
- **USB-C** — powers the board and lets you program the RP2040
- **DIP switches** — manual input (directly connected to chip pins)
- **7-segment display** — shows output values
- **LED bar** — shows individual output bits
- **PMODs** — breakout headers for connecting logic analyzers, extra hardware, etc.

### How It Works: RP2040 = Program Memory

Our CPU has **no internal ROM** — it reads instructions from its input pins every clock cycle. The **RP2040 microcontroller** on the demo board acts as the external program memory.

```
The loop (runs continuously):

┌─────────┐    PC (4-bit)      ┌──────────┐
│  ASIC   │ ──────────────────►│  RP2040  │
│  (CPU)  │    uio[3:0]        │          │
│         │◄───────────────────│ program  │
│         │    ui_in[7:0]      │ ROM[]    │
└─────────┘    (8-bit instr)   └──────────┘

1. CPU outputs its PC on uio[3:0]           → "I need instruction at address 5"
2. RP2040 reads PC from those pins          → "Address 5, let me look that up"
3. RP2040 writes program[5] to ui_in[7:0]   → "Here's instruction 0x21 (ADD 1)"
4. CPU latches instruction on next clk edge → executes ADD 1
5. Repeat!
```

The RP2040 also reads the output pins (`uo_out`) and can display the accumulator value on LEDs, log it over serial, etc.

### RP2040 Firmware (MicroPython)

Flash this to the RP2040 on the TinyTapeout board:

```python
import machine
import time

# ── YOUR PROGRAM ── change this to run different programs!
# Counter: counts 0 → 1 → 2 → ... → 15 → 0 then halts
program = [
    0x10,  # LDI 0    — load 0 into accumulator
    0x21,  # ADD 1    — add 1
    0xD1,  # JNZ 1    — jump to addr 1 if not zero
    0xF0,  # HLT      — halt
    0x00, 0x00, 0x00, 0x00,  # unused addresses (NOP)
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
]

# Pin setup (adjust pin numbers for your TT board revision)
ui_pins  = [machine.Pin(i, machine.Pin.OUT) for i in range(0, 8)]   # ui_in[7:0]
pc_pins  = [machine.Pin(i, machine.Pin.IN)  for i in range(16, 20)] # uio[3:0]
acc_pins = [machine.Pin(i, machine.Pin.IN)  for i in range(8, 12)]  # uo_out[3:0]

def read_pc():
    """Read 4-bit program counter from the chip."""
    val = 0
    for i in range(4):
        val |= (pc_pins[i].value() << i)
    return val

def read_acc():
    """Read 4-bit accumulator from the chip."""
    val = 0
    for i in range(4):
        val |= (acc_pins[i].value() << i)
    return val

def write_instruction(instr):
    """Write 8-bit instruction to the chip's input pins."""
    for i in range(8):
        ui_pins[i].value((instr >> i) & 1)

# Main loop — act as program memory
print("Nibble CPU running...")
while True:
    pc = read_pc()
    instr = program[pc & 0x0F]   # mask to 4 bits (16 addresses)
    write_instruction(instr)
    acc = read_acc()
    print(f"PC={pc}  INSTR=0x{instr:02X}  ACC={acc}")
```

### RP2040 Firmware (C / Arduino)

For lower latency, use C firmware via the Arduino IDE:

```c
// Flash via Arduino IDE with "Raspberry Pi Pico" board selected
#include <Arduino.h>

// ── YOUR PROGRAM ── Counter (0 → 15 → halt)
uint8_t program[16] = {
    0x10,  // LDI 0
    0x21,  // ADD 1
    0xD1,  // JNZ 1
    0xF0,  // HLT
    0x00, 0x00, 0x00, 0x00,  // unused
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
};

// Pin assignments (adjust for your TT board revision)
const int UI_PINS[8]  = {0, 1, 2, 3, 4, 5, 6, 7};    // ui_in[7:0]
const int PC_PINS[4]  = {16, 17, 18, 19};              // uio[3:0]
const int ACC_PINS[4] = {8, 9, 10, 11};                // uo_out[3:0]

void setup() {
    Serial.begin(115200);
    for (int i = 0; i < 8; i++) pinMode(UI_PINS[i], OUTPUT);
    for (int i = 0; i < 4; i++) pinMode(PC_PINS[i], INPUT);
    for (int i = 0; i < 4; i++) pinMode(ACC_PINS[i], INPUT);
    Serial.println("Nibble CPU running...");
}

void loop() {
    // 1. Read PC from chip
    uint8_t pc = 0;
    for (int i = 0; i < 4; i++)
        pc |= (digitalRead(PC_PINS[i]) << i);

    // 2. Look up instruction in program ROM
    uint8_t instr = program[pc & 0x0F];

    // 3. Drive instruction to chip's input pins
    for (int i = 0; i < 8; i++)
        digitalWrite(UI_PINS[i], (instr >> i) & 1);

    // 4. Read accumulator and print to serial monitor
    uint8_t acc = 0;
    for (int i = 0; i < 4; i++)
        acc |= (digitalRead(ACC_PINS[i]) << i);

    Serial.printf("PC=%d  INSTR=0x%02X  ACC=%d\n", pc, instr, acc);
}
```

### Step-by-Step Testing

1. **Connect the board** via USB-C to your computer
   - This powers the board and gives you serial/programming access

2. **Select your design** on the TinyTapeout board
   - Use the TT Commander app or DIP switches to select your project's index number

3. **Flash the RP2040** with one of the firmware files above
   - MicroPython: copy the `.py` file to the Pico's drive
   - C/Arduino: flash via Arduino IDE with "Raspberry Pi Pico" board selected

4. **Press reset** — the CPU starts executing!
   - The reset button pulls `rst_n` LOW then releases HIGH
   - The CPU begins at `PC=0` in FETCH phase

5. **Watch the LEDs** — the accumulator value appears on `uo_out[3:0]`
   - Counter program: LEDs count 0000 → 0001 → 0010 → ... → 1111 → stop

6. **Open a serial monitor** to see cycle-by-cycle execution
   - Arduino IDE: Serial Monitor at 115200 baud
   - Terminal: `screen /dev/ttyACM0 115200` (Linux/Mac) or use PuTTY (Windows)

### What You'll See

**Serial monitor output (counter program):**

```
Nibble CPU running...
PC=0  INSTR=0x10  ACC=0       ← LDI 0
PC=1  INSTR=0x21  ACC=0       ← fetching ADD 1
PC=1  INSTR=0x21  ACC=1       ← executed: A = 0 + 1 = 1
PC=2  INSTR=0xD1  ACC=1       ← JNZ 1 (A≠0, branching!)
PC=1  INSTR=0x21  ACC=1       ← back at ADD 1
PC=1  INSTR=0x21  ACC=2       ← A = 1 + 1 = 2
...
PC=1  INSTR=0x21  ACC=15      ← A = 14 + 1 = 15
PC=1  INSTR=0x21  ACC=0       ← A = 15 + 1 = 0 (overflow!)
PC=2  INSTR=0xD1  ACC=0       ← JNZ 1 (A=0, NOT branching)
PC=3  INSTR=0xF0  ACC=0       ← HLT — CPU stopped!
```

**LED output pins:**

```
uo_out[3:0]  uo_out[4]  uo_out[5]  uo_out[6]  uo_out[7]
(accumulator) (carry)    (zero)     (halted)   (phase)
─────────────────────────────────────────────────────────
 0000          0          1          0          blinking   ← start (A=0, Z=1)
 0001          0          0          0          blinking   ← A=1
 0010          0          0          0          blinking   ← A=2
 ...counting up...
 1111          0          0          0          blinking   ← A=15
 0000          1          1          1          stopped    ← halted! (C=1, Z=1)
```

### Demo Programs for the PCB

Change the `program[]` array in the firmware to try these:

**Fibonacci on LEDs** — watch 0, 1, 1, 2, 3, 5, 8, 13:

```python
program = [
    0x10,  # LDI 0   → ACC=0
    0x21,  # ADD 1   → ACC=1
    0x20,  # ADD 0   → ACC=1
    0x21,  # ADD 1   → ACC=2
    0x21,  # ADD 1   → ACC=3
    0x22,  # ADD 2   → ACC=5
    0x23,  # ADD 3   → ACC=8
    0x25,  # ADD 5   → ACC=13
    0xF0,  # HLT
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]
```

**Knight Rider** — LED bounces left and right forever:

```python
program = [
    0x11,  # LDI 1   → 0001
    0x80,  # SHL     → 0010
    0x80,  # SHL     → 0100
    0x80,  # SHL     → 1000
    0x90,  # SHR     → 0100
    0x90,  # SHR     → 0010
    0xA0,  # JMP 0   → loop back!
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]
```

**Countdown from 15** — counts down and halts:

```python
program = [
    0x1F,  # LDI 15  → ACC=15
    0x31,  # SUB 1   → ACC=14, 13, 12, ...
    0xD1,  # JNZ 1   → loop until ACC=0
    0xF0,  # HLT
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
]
```

### Using DIP Switches as Input

The **IN** instruction (`0xE0`) reads the 4-bit value from `uio[7:4]`. On the TinyTapeout board, you can connect DIP switches to these pins so users can interact with the CPU in real time.

```
DIP Switches                          LEDs
┌───┬───┬───┬───┐                    ┌───┬───┬───┬───┐
│ 3 │ 2 │ 1 │ 0 │ ← set a number    │ 3 │ 2 │ 1 │ 0 │ ← see result
└─┬─┴─┬─┴─┬─┴─┬─┘                    └─▲─┴─▲─┴─▲─┴─▲─┘
  │   │   │   │                          │   │   │   │
uio[7] [6] [5] [4]                  uo_out[3] [2] [1] [0]
  │   │   │   │                          │   │   │   │
  └───┴───┴───┴──────► ASIC ────────────┴───┴───┴───┘
```

**Example: "Double the input" program:**

```
Addr  Hex   Assembly    What it does
----  ----  ---------   ---------------------------
0x0   0xE0  IN          Read DIP switches into A
0x1   0x80  SHL         Shift left = multiply by 2
0x2   0xF0  HLT         Show result on LEDs
```

Set DIP = 0101 (5) → LEDs show 1010 (10)!
Set DIP = 0011 (3) → LEDs show 0110 (6)!

**Example: "Is input zero?" program:**

```
Addr  Hex   Assembly    What it does
----  ----  ---------   ---------------------------
0x0   0xE0  IN          Read DIP switches into A
0x1   0xB4  JZ 4        If zero, jump to addr 4
0x2   0x10  LDI 0       Not zero: output 0
0x3   0xF0  HLT         Halt
0x4   0x11  LDI 1       Zero: output 1
0x5   0xF0  HLT         Halt
```

### Clock Speed Tips

The RP2040 generates the clock for the ASIC. Adjusting the clock speed is key for demos vs debugging:

| Clock Speed | Use Case |
|-------------|----------|
| **1 - 10 Hz** | Debugging — watch each instruction execute in real-time, count LED changes by eye |
| **~2 Hz** | Demo — counter program counts visibly |
| **~4 Hz** | Demo — Knight Rider LED sweep looks smooth |
| **1 kHz** | Fast execution — results appear instantly but RP2040 can still keep up |
| **1 MHz** | Full speed — 500,000 instructions/sec, RP2040 must be optimized to keep up |

> **How to set clock speed:** The TT board generates the clock from the RP2040. Configure it in the TinyTapeout SDK, or set it manually via the RP2040 firmware using a PWM output. Default is typically 10 MHz — **slow it down for visual demos!**

### Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| All LEDs off | Wrong project selected | Check project index on DIP switches or TT Commander app |
| LEDs stuck at 0000 | CPU in reset or halted | Press reset button; check RP2040 firmware is running |
| Random LED pattern | RP2040 not driving instructions | Reflash firmware; check pin assignments match your board revision |
| Phase LED not blinking | Clock not running | Check clock source setting; try a slower clock for debugging |
| Halted LED on immediately | First instruction is HLT or memory is all zeros | Check `program[]` array starts with valid instructions |
| Accumulator shows wrong values | Clock too fast for RP2040 loop | Slow clock to 1 kHz or add a delay in the RP2040 firmware |
| Serial monitor shows garbage | Wrong baud rate | Set serial monitor to 115200 baud |
| "No device found" when flashing | RP2040 not in bootloader mode | Hold BOOTSEL button while plugging in USB |

---

## Repository Structure

```
├── src/
│   ├── project.v            TinyTapeout wrapper (top module)
│   ├── cpu_core.v           4-bit CPU core (ALU, registers, FSM)
│   └── config.json          OpenLane configuration for TT IHP
├── test/
│   ├── tb.v                 Testbench (6 test suites, 51 checks)
│   └── sg13g2_functional.v  Functional cell models for gate-level sim
├── flow/
│   ├── synth.ys             Yosys synthesis script
│   └── synth.tcl            Alternative Tcl synthesis script
├── docs/
│   └── info.md              TinyTapeout project documentation
├── workshop/
│   └── slides.html          Workshop presentation (open in browser)
├── outputs/                  Generated: netlists, stats (gitignored)
├── info.yaml                TinyTapeout project config (yaml v6)
├── Makefile                 Build targets: test, synth, test_gl, wave
└── README.md                This file
```

---

## License

This project is open source under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).
