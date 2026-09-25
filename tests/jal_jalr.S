    .globl _start
_start:
    jal  ra, L1
    j    f_skip1
L1:
    li   t2, 4
    bne  ra, t2, f_link1
    la   t3, L2
    jalr t4, 0(t3)
after:
    j    f_skip2
L2:
    la   t5, after
    bne  t4, t5, f_link2
    li   t0, 0x7f0
    li   t1, 1
    sw   t1, 0(t0)
1:  j    1b

f_skip1: li t1, 2
    j    report
f_link1: li t1, 3
    j    report
f_skip2: li t1, 4
    j    report
f_link2: li t1, 5
report:
    li   t0, 0x7f0
    sw   t1, 0(t0)
2:  j    2b
