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
    MD   div,  42, 6, 7, 1
    MD   div,  -42, 5, -8, 2
    MD   rem,  -42, 5, -2, 3
    MD   divu, 0xfffffffe, 2, 0x7fffffff, 4
    MD   remu, 43, 5, 3, 5
    MD   div,  5, 0, -1, 6
    MD   divu, 5, 0, -1, 7
    MD   rem,  5, 0, 5, 8
    MD   remu, 5, 0, 5, 9
    MD   div,  0x80000000, -1, 0x80000000, 10
    MD   rem,  0x80000000, -1, 0, 11
    li   t2, 84
    li   t3, 12
    div  t1, t2, t3
    add  t4, t1, t1
    CHECK t4, 14, 12
    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
