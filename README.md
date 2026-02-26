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
- [Tool Installation](#tool-installation)
  - [macOS](#macos)
  - [Windows](#windows-wsl2)
  - [Linux (Ubuntu/Debian)](#linux-ubuntudebian)
- [Quick Start](#quick-start)
- [Workshop Guide](#workshop-guide)
- [Synthesis Results](#synthesis-results)
- [Testing with TinyTapeout Board](#testing-with-tinytapeout-board)

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

### Verify Your Setup

After installation on any OS, clone this repo and run:

```bash
git clone https://github.com/fidel-makatia/Tinytapeout_4bitCPU.git
cd Tinytapeout_4bitCPU

# RTL simulation (works everywhere)
make test

# Synthesis to IHP cells (requires yosys + IHP PDK)
IHP_PDK=~/IHP-Open-PDK make synth

# Gate-level simulation (requires iverilog + IHP PDK)
IHP_PDK=~/IHP-Open-PDK make test_gl
```

Expected output:
```
  RESULTS: 51 / 51 passed
  ALL TESTS PASSED
```

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

## Testing with TinyTapeout Board

The TinyTapeout demo board has an **RP2040** microcontroller that drives the input pins.
Program the RP2040 to act as the CPU's program memory:

```c
// RP2040 firmware pseudocode
uint8_t program[] = {0x10, 0x21, 0xD1, 0xF0};  // counter program

while (1) {
    uint8_t pc = read_gpio(uio[3:0]);     // read PC from chip
    uint8_t instr = program[pc & 0x0F];   // look up instruction
    write_gpio(ui_in[7:0], instr);        // drive instruction to chip
}
```

Connect LEDs to `uo_out[3:0]` to see the accumulator counting!

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
├── outputs/                  Generated: netlists, stats (gitignored)
├── info.yaml                TinyTapeout project config (yaml v6)
├── Makefile                 Build targets: test, synth, test_gl, wave
└── README.md                This file
```

---

## License

This project is open source under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).
