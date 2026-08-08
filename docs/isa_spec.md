# Custom-0 ISA Specification

Status: Draft v0.1 for team freeze
Owner: Shriram Kumar V
Related module: nmc_unit

## RISC-V opcode used

Opcode: custom-0
Binary opcode: 0001011
Hex opcode: 0x0B

## Instruction format

All four accelerator instructions use R-type encoding.

R-type format:

| Field   | Bits  |
|---------|-------|
| funct7  | 31:25 |
| rs2     | 24:20 |
| rs1     | 19:15 |
| funct3  | 14:12 |
| rd      | 11:7  |
| opcode  | 6:0   |

Opcode for all instructions: 0001011

## Instruction summary

| Instruction | opcode   | funct3 | funct7  | Purpose |
|-------------|----------|--------|---------|---------|
| nmc.ldw     | 0001011  | 000    | 0000000 | Load weights into accelerator |
| nmc.lda     | 0001011  | 001    | 0000000 | Load activations into accelerator |
| nmc.run     | 0001011  | 010    | 0000000 | Start accelerator operation |
| nmc.rd      | 0001011  | 011    | 0000000 | Read result/status from accelerator |

## Instruction behavior

### nmc.ldw

Purpose:
Load binary weights from memory into the near-memory accelerator array.

Proposed operands:
- rs1: base address of weight data in memory
- rs2: number of 32-bit words or transfer length
- rd: optional status/tag, may be x0

Behavior:
- Non-blocking issue
- Starts weight load operation
- Completion observed through status CSR or later nmc.rd

### nmc.lda

Purpose:
Load activation data into the accelerator.

Proposed operands:
- rs1: base address of activation data
- rs2: number of 32-bit words or transfer length
- rd: optional status/tag, may be x0

Behavior:
- Non-blocking issue
- Starts activation load operation

### nmc.run

Purpose:
Start the accelerator operation.

Proposed operands:
- rs1: layer configuration address or operation selector
- rs2: additional configuration value
- rd: optional status/tag, may be x0

Behavior:
- Non-blocking issue
- Starts convolution/threshold/pool operation

### nmc.rd

Purpose:
Read result or status from accelerator.

Proposed operands:
- rd: destination register for result/status
- rs1: select/status control
- rs2: reserved

Behavior:
- May be blocking read
- Used to read back results or completion status

## CSR

Proposed custom machine-mode CSR:

| CSR address | Name        | Purpose |
|-------------|-------------|---------|
| 0x7C0       | nmc_status  | Accelerator status |

Status bits to define later:
- busy
- done
- error
- ready

## Notes

This specification must be frozen quickly so Member B can build:
- bit-accurate C golden model
- bare-metal C driver using `.insn r`
- verification tests

Any change after freeze must be documented.
