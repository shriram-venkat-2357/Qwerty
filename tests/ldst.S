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
    li   t0, 0x8081ff7f
    PAD
    sw   t0, 0(s0)
    PAD
    lw   t1, 0(s0)
    PAD
    CHECK t1, 0x8081ff7f, 1
    lb   t1, 0(s0)
    PAD
    CHECK t1, 0x7f, 2
    lb   t1, 1(s0)
    PAD
    CHECK t1, -1, 3
    lbu  t1, 1(s0)
    PAD
    CHECK t1, 0xff, 4
    lh   t1, 0(s0)
    PAD
    CHECK t1, -129, 5
    lhu  t1, 0(s0)
    PAD
    CHECK t1, 0xff7f, 6
    lh   t1, 2(s0)
    PAD
    CHECK t1, -32639, 7
    lhu  t1, 2(s0)
    PAD
    CHECK t1, 0x8081, 8
    li   t0, 0x11223344
    PAD
    sw   t0, 4(s0)
    li   t2, 0xAB
    PAD
    sb   t2, 5(s0)
    li   t2, 0xCDEF
    PAD
    sh   t2, 6(s0)
    PAD
    lw   t1, 4(s0)
    PAD
    CHECK t1, 0xCDEFAB44, 9
    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
