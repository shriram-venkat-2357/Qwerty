    .globl _start
_start:
    li   t2, 5
    li   t3, 7
    li   t5, 12
    .rept 3
    nop
    .endr
    add  t4, t2, t3
    .rept 3
    nop
    .endr
    bne  t4, t5, fail

    li   t0, 0x7f0
    .rept 3
    nop
    .endr
    li   t1, 1
    .rept 3
    nop
    .endr
    sw   t1, 0(t0)
1:  j    1b

fail:
    li   t0, 0x7f0
    li   t1, 2
    .rept 3
    nop
    .endr
    sw   t1, 0(t0)
2:  j    2b
