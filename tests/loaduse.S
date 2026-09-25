    .macro PAD
    nop
    nop
    nop
    nop
    .endm

    .macro CHECK r, val, code
    li   t6, \val
    PAD
    beq  \r, t6, 1f
    li   t5, \code+100
    j    report
1:
    .endm

    .globl _start
_start:
    li   s0, 0x100
    li   t0, 5
    li   t2, 7
    li   t3, 0x100
    PAD
    sw   t0, 0(s0)
    sw   t2, 4(s0)
    sw   t3, 8(s0)
    PAD

    lw   t1, 0(s0)
    add  t4, t1, t1
    PAD
    CHECK t4, 10, 1

    lw   t1, 0(s0)
    lw   t2, 4(s0)
    add  t4, t1, t2
    PAD
    CHECK t4, 12, 2

    lw   t1, 8(s0)
    lw   t2, 0(t1)
    PAD
    CHECK t2, 5, 3

    lw   t1, 4(s0)
    sw   t1, 12(s0)
    PAD
    lw   t2, 12(s0)
    PAD
    CHECK t2, 7, 4

    lw   t1, 0(s0)
    addi t4, t1, 1
    PAD
    CHECK t4, 6, 5

    lw   t1, 0(s0)
    bne  t1, zero, 1f
    li   t5, 106
    j    report
1:
    li   t3, 0x55
    PAD
    lw   t1, 8(s0)
    sw   t3, 16(t1)
    PAD
    lw   t2, 16(s0)
    PAD
    CHECK t2, 0x55, 7

    li   t4, 0
    PAD
    lw   t1, 0(s0)
    add  t3, t1, t1
    addi t4, t4, 1
    addi t4, t4, 1
    addi t4, t4, 1
    PAD
    CHECK t4, 3, 8

    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
