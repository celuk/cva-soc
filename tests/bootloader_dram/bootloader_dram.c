#include <stdint.h>
#include "timer.h"
#include "uart.h"
#include "defines.h"

#define DDR3_AXI_BASE_ADDR 0x80000000
#define DDR3_AXI_CODE_BASE_ADDR (DDR3_AXI_BASE_ADDR + 0x100)

void init()
{
    init_uart();
    init_timer();
    wait_for_us(500);
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        "li    t0, 0x80000000 \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

static inline void jump_to_dram()
{
    asm volatile (
        "lui   t0, 0x80000 \n"
        "addi  t0, t0, 0x100 \n"
        "jalr  x0, t0, 0 \n"
    );
}

int main()
{
    init();
    //update_trap_vector_base_address();
    //jump_to_dram();
    unsigned int data;
    unsigned int address = DDR3_AXI_CODE_BASE_ADDR;

    data = *((volatile unsigned int*)(address+4));
    tekno_printf("data: %x address: %x\n", data, address+4);

    address += 4;
    data = *((volatile unsigned int*)(address));
    tekno_printf("data: %x address: %x\n", data, address);
    address += 4;
    data = *((volatile unsigned int*)(address));
    tekno_printf("data: %x address: %x\n", data, address);
    return 0;
}
