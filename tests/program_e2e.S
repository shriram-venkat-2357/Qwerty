.section .text
.globl _start
_start:
    # 1. Setup: Load first 4 words of REAL weights into x1-x4
    li x1, 0x508b7dab
    li x2, 0x55e1dd7b
    li x3, 0x213654c5
    li x4, 0x2d0111c1

    # 2. Stage these 4 words of weights in DMEM at 0x000
    sw x1, 0(x0)
    sw x2, 4(x0)
    sw x3, 8(x0)
    sw x4, 12(x0)

    # 3. Stage 4 words of activations (all-ones) in DMEM at 0x100 (256)
    li x5, -1
    sw x5, 256(x0)
    sw x5, 260(x0)
    sw x5, 264(x0)
    sw x5, 268(x0)

    # 4. Setup registers for accelerator
    li x6, 256      # x6 = act base (256)
    li x7, 4        # x7 = act word count (4)
    li x8, 0        # x8 = weight base (0)
    li x9, 4        # x9 = weight row count (4)

    # 5. Accelerator Sequence (Custom-0 opcodes)
    # nmc.ldw x0, x8, x9  (funct3=000)
    .word 0x0098000B
    # nmc.lda x0, x6, x7  (funct3=001)
    .word 0x0076100B
    # nmc.run x0, x0, x0  (funct3=010)
    .word 0x0000200B

    # 6. Poll Status CSR (0x7C0) for 'done' (bit 1)
poll_loop:
    csrr x10, 0x7C0
    andi x11, x10, 2
    beq x11, x0, poll_loop

    # 7. Readback result into x12
    # nmc.rd x12, x0, x0  (funct3=011)
    .word 0x0000360B

    # 8. Store result to DMEM at 0x3FC for testbench checking
    sw x12, 1020(x0)

    # 9. Infinite loop (halt)
halt:
    j halt
