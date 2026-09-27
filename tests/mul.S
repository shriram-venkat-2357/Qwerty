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

    .macro MD op, a, b, want, code
    li   t1, \a
    li   t2, \b
    PAD
    \op  t3, t1, t2
    CHECK t3, \want, \code
    .endm

    .globl _start
_start:
    MD   mul,    7, 6, 42, 1
    MD   mul,    -3, 5, -15, 2
    MD   mulh,   0x80000000, 2, -1, 3
    MD   mulhu,  0x80000000, 2, 1, 4
    MD   mulhsu, -1, 2, -1, 5
    MD   mulh,   -1, -1, 0, 6
    MD   mulhu,  -1, -1, 0xfffffffe, 7
    li   t2, 7
    li   t3, 6
    mul  t1, t2, t3
    add  t4, t1, t1
    CHECK t4, 84, 8
    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
