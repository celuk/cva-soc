.globl _start
_start:
    li   x5, 10
loop:
    addi x5, x5, -1
    bnez x5, loop

print:
    # UART base addresses
    li   t0, 0xFF000010    # UART_CFG
    li   t1, 0xFF000000    # UART_CPB
    li   t2, 0xFF000004    # UART_STP
    li   t3, 0xFF00000C    # UART_TDR

    # UART_CFG |= 0x7
    lw   t4, 0(t0)
    ori  t4, t4, 0x7
    sw   t4, 0(t0)

    # UART_CPB = 217
    li   t4, 217
    sw   t4, 0(t1)

    # UART_STP |= 0x1
    lw   t4, 0(t2)
    ori  t4, t4, 0x1
    sw   t4, 0(t2)

    # Print x5 as a character ('0' + x5)
    li   t4, 0xFF          # mask for lower 8 bits if needed
    and  t5, x5, t4        # t5 = x5 & 0xFF
    addi t5, t5, 48        # convert to ASCII: '0' = 48
    sw   t5, 0(t3)         # UART_TDR = character

    # UART_CFG = UART_CFG | 0x1 (enable transfer)
    lw   t4, 0(t0)
    ori  t4, t4, 0x1
    sw   t4, 0(t0)

hang:
    j    hang
