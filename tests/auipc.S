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
    auipc t1, 1
    CHECK t1, 0x1000, 1
3:  auipc t2, 0
    la   t3, 3b
    PAD
    beq  t2, t3, 2f
    li   t5, 102
    j    report
2:
    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
