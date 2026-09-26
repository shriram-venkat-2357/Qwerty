    .globl _start
_start:
    li   t2, 5
    li   t3, 7
    add  t4, t2, t3
    li   t5, 12
    bne  t4, t5, fail

    li   t0, 0xFF0
    li   t1, 1
    sw   t1, 0(t0)      # PASS
1:  j    1b

fail:
    li   t0, 0xFF0
    li   t1, 2
    sw   t1, 0(t0)      # FAIL, code 2
2:  j    2b
