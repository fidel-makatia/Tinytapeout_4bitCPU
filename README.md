# Nibble — 4-bit CPU for TinyTapeout IHP

A minimal 4-bit accumulator CPU designed for TinyTapeout IHP (SG13G2 130nm). Fits in a single tile (~300 standard cells).

## Architecture

- 4-bit accumulator, 4-bit program counter
- 16-instruction ISA with ALU, shifts, branches, and I/O
- 2-cycle fetch-execute pipeline
- External program memory (Harvard architecture)

## Instruction Set

```
Opcode  Mnemonic    Operation               Flags
------  --------    ---------               -----
0x0     NOP         No operation            -
0x1     LDI imm     A = imm                 Z
0x2     ADD imm     A = A + imm             C, Z
0x3     SUB imm     A = A - imm             C, Z
0x4     AND imm     A = A & imm             Z
0x5     OR  imm     A = A | imm             Z
0x6     XOR imm     A = A ^ imm             Z
0x7     NOT         A = ~A                  Z
0x8     SHL         {C,A} = {A[3],A<<1}     C, Z
0x9     SHR         {A,C} = {A>>1,A[0]}     C, Z
0xA     JMP addr    PC = addr               -
0xB     JZ  addr    if Z: PC = addr         -
0xC     JC  addr    if C: PC = addr         -
0xD     JNZ addr    if !Z: PC = addr        -
0xE     IN          A = input port          Z
0xF     HLT         Halt execution          -
```

Instruction encoding: `[7:4] = opcode`, `[3:0] = immediate/address`

## TinyTapeout Pin Mapping

| Pin | Direction | Signal |
|-----|-----------|--------|
| `ui_in[7:0]` | Input | Instruction data (from external ROM / RP2040) |
| `uo_out[3:0]` | Output | Accumulator value (connect LEDs!) |
| `uo_out[4]` | Output | Carry flag |
| `uo_out[5]` | Output | Zero flag |
| `uo_out[6]` | Output | Halted |
| `uo_out[7]` | Output | Phase (0=fetch, 1=execute) |
| `uio[3:0]` | Output | Program counter (address bus) |
| `uio[7:4]` | Input | General-purpose input port |

## Example Programs

**Counter (counts 0-15 on LEDs):**
```
0: LDI 0    (0x10)
1: ADD 1    (0x21)
2: JNZ 1    (0xD1)
3: HLT      (0xF0)
```

**Fibonacci (0,1,1,2,3,5,8,13):**
```
0: LDI 0    (0x10)
1: ADD 1    (0x21)
2: ADD 0    (0x20)
3: ADD 1    (0x21)
4: ADD 1    (0x21)
5: ADD 2    (0x22)
6: ADD 3    (0x23)
7: ADD 5    (0x25)
8: HLT      (0xF0)
```

## Quick Start

```bash
make test    # Run verification (requires iverilog)
make wave    # View waveforms (requires gtkwave)
```

## Testing with TinyTapeout Board

The RP2040 on the TT demo board acts as program memory:
1. Read PC from `uio[3:0]` (4-bit address)
2. Look up instruction in a table
3. Drive `ui_in[7:0]` with the instruction byte

Clock the CPU at 1 MHz or lower to observe results on LEDs.
