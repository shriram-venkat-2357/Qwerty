    .section .text.start
    .globl _start
_start:
    li   t4, 0x10000000
    li   a0, 0
    li   a1, 0
    .insn r 0x0b, 4, 0, x0, a0, a1
    li   a0, 0
    li   a1, 39
    .insn r 0x0b, 0, 0, x0, a0, a1
    li   a2, 0x100
    li   a3, 16
    .insn r 0x0b, 1, 0, x0, a2, a3
    .insn r 0x0b, 2, 0, x0, x0, x0
L_poll:
    csrr t2, 0x7C0
    andi t3, t2, 1
    bnez t3, L_poll
    .insn r 0x0b, 3, 0, a4, x0, x0
    sw   a4, 0x300(t4)
    li   a5, 0xCAFEF00D
    sw   a5, 0x320(t4)
L_halt:
    j    L_halt
