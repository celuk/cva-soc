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

    *((volatile unsigned int*)(address)) = 0x00A00293;
    *((volatile unsigned int*)(address+8)) = 0x00B00294;
    *((volatile unsigned int*)(address+4)) = 0x00C00295;
    *((volatile unsigned int*)(address+12)) = 0x00D00296;

    *((volatile unsigned int*)(address+32)) = 0x00A00293;
    *((volatile unsigned int*)(address+36)) = 0x00B00294;
    *((volatile unsigned int*)(address+40)) = 0x00C00295;
    *((volatile unsigned int*)(address+44)) = 0x00D00296;
    *((volatile unsigned int*)(address+48)) = 0x00D00296;

    *((volatile unsigned int*)(DDR3_AXI_BASE_ADDR)) = 0x00D00296;
    *((volatile unsigned int*)(DDR3_AXI_BASE_ADDR+8)) = 0x00D00296;
    *((volatile unsigned int*)(DDR3_AXI_BASE_ADDR+60)) = 0x00D00296;

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
