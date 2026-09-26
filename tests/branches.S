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

    .macro BT op, a, b, code
    li   t1, \a
    li   t2, \b
    PAD
    \op  t1, t2, 2f
    li   t4, 7
    li   t5, \code+100
    j    report
2:
    .endm

    .macro BN op, a, b, code
    li   t1, \a
    li   t2, \b
    PAD
    \op  t1, t2, 3f
    j    4f
3:  li   t5, \code+100
    j    report
4:
    .endm

    .globl _start
_start:
    li   t4, 0
    BT   beq,  5, 5, 1
    BN   beq,  5, 6, 2
    BT   bne,  5, 6, 3
    BN   bne,  5, 5, 4
    BT   blt,  -1, 1, 5
    BN   blt,  1, -1, 6
    BN   blt,  3, 3, 7
    BT   bge,  1, -1, 8
    BT   bge,  3, 3, 9
    BN   bge,  -1, 1, 10
    BT   bltu, 1, -1, 11
    BN   bltu, -1, 1, 12
    BT   bgeu, -1, 1, 13
    BT   bgeu, 3, 3, 14
    BN   bgeu, 1, -1, 15

    li   t1, 3
    li   t2, 0
    PAD
loop:
    addi t2, t2, 1
    addi t1, t1, -1
    bne  t1, zero, loop
    PAD
    CHECK t2, 3, 16
    CHECK t4, 0, 17
    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
