    .globl _start
_start:
    li   x5, 10           # loop count = 10
loop:
    addi x5, x5, -1       # decrement
    bnez x5, loop         # if x5 != 0, repeat

print:
    # --- UART init ---
    li   x6, 0xFF000010   # UART_CFG addr
    li   x7, 0xFF000000   # UART_CPB  addr
    li   x8, 0xFF000004   # UART_STP  addr
    li   x9, 0xFF00000C   # UART_TDR  addr

    # UART_CFG |= 0x7
    lw   x10, 0(x6)
    ori  x10, x10, 7
    sw   x10, 0(x6)

    fence

    # UART_CPB = 217
    li   x10, 217
    sw   x10, 0(x7)

    fence

    # UART_STP |= 0x1
    lw   x10, 0(x8)
    ori  x10, x10, 1
    sw   x10, 0(x8)

    fence

    # wait until UART_CFG & 0x4 != 0
    #jal  x1, uart_tx_full

    # prepare ASCII digit ('0' + x5)
    andi x11, x5, 0xFF
    addi x11, x11, 48

    # write character
    sw   x11, 0(x9)

    fence

    # wait again until TX not full
    #jal  x1, uart_tx_full

    # finally enable transmitter: UART_CFG |= 0x1
    lw   x10, 0(x6)
    ori  x10, x10, 1
    sw   x10, 0(x6)

    fence

hang:
    j    hang            # infinite loop

#------------------------------------------------
# Poll UART_CFG bit-2 until it becomes 1:
uart_tx_full:
    lw   x10, 0(x6)       # read UART_CFG
    andi x10, x10, 4      # mask bit-2
    beq  x10, x0, uart_tx_full
    ret
