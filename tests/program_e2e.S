.section .text
.globl _start
_start:
    # 1. Setup: x1 = 0xFFFFFFFF (All-ones pattern)
    li x1, -1

    # 2. Stage 4 words of weights in DMEM at 0x000
    sw x1, 0(x0)
    sw x1, 4(x0)
    sw x1, 8(x0)
    sw x1, 12(x0)

    # 3. Stage 4 words of activations in DMEM at 0x100 (256)
    sw x1, 256(x0)
    sw x1, 260(x0)
    sw x1, 264(x0)
    sw x1, 268(x0)

    # 4. Setup registers for accelerator
    li x2, 256      # x2 = act base (256)
    li x3, 4        # x3 = act word count (4)
    li x4, 0        # x4 = weight base (0)
    li x5, 4        # x5 = weight row count (4)

    # 5. Accelerator Sequence (Custom-0 opcodes encoded as raw hex)
    
    # nmc.ldw x0, x4, x5 
    # Opcode=0x0B, funct3=0, rd=x0, rs1=x4, rs2=x5, funct7=0
    # Binary: 0000000 00101 00100 000 00000 0001011 -> Hex: 0x0054000B
    .word 0x0054000B
    
    # nmc.lda x0, x2, x3
    # Opcode=0x0B, funct3=1, rd=x0, rs1=x2, rs2=x3, funct7=0
    # Binary: 0000000 00011 00010 001 00000 0001011 -> Hex: 0x0032100B
    .word 0x0032100B
    
    # nmc.run x0, x0, x0
    # Opcode=0x0B, funct3=2, rd=x0, rs1=x0, rs2=x0, funct7=0
    # Binary: 0000000 00000 00000 010 00000 0001011 -> Hex: 0x0000200B
    .word 0x0000200B

    # 6. Poll Status CSR (0x7C0) for 'done' (bit 1)
poll_loop:
    csrr x6, 0x7C0
    andi x7, x6, 2
    beq x7, x0, poll_loop

    # 7. Readback result into x8
    # nmc.rd x8, x0, x0
    # Opcode=0x0B, funct3=3, rd=x8, rs1=x0, rs2=x0, funct7=0
    # Binary: 0000000 00000 00000 011 01000 0001011 -> Hex: 0x0000340B
    .word 0x0000340B

    # 8. Store result to DMEM at 0x3FC for testbench checking
    sw x8, 1020(x0)

    # 9. Infinite loop (halt)
halt:
    j halt
