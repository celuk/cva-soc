.globl _start
_start:
    li   x5, 10
loop:
    addi x5, x5, -1
    bnez x5, loop
hang:
    j    hang
