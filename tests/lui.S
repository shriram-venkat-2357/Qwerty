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
    lui  t1, 0x12345
    CHECK t1, 0x12345000, 1
    lui  t2, 0xfffff
    CHECK t2, 0xfffff000, 2
    lui  t3, 1
    addi t3, t3, -16
    CHECK t3, 0xff0, 3
    li   t5, 1
report:
    li   t0, 0x7f0
    PAD
    sw   t5, 0(t0)
1:  j    1b
