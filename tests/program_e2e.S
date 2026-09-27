.text
.globl _start
_start:
    li t0, 0x00020000
    li t1, 128
    .insn r 0x0B, 0, 0, x0, t0, t1

    li t0, 0x00020400
    li t1, 4
    .insn r 0x0B, 1, 0, x0, t0, t1

    .insn r 0x0B, 2, 0, x0, x0, x0

poll:
    li t0, 0x7C0
    csrr t1, t0
    andi t1, t1, 1
    bnez t1, poll

    .insn r 0x0B, 3, 0, a0, x0, x0

    li t0, 0x00020800
    sw a0, 0(t0)
