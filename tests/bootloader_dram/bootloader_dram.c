#include <stdint.h>
#include "timer.h"

#define CODE_RAM_BASE_ADDR 0x00002000
#define CODE_RAM (*(volatile uint32_t*) (CODE_RAM_BASE_ADDR))

#define DDR3_AXI_BASE_ADDR 0x80000000

void load_code_through_dram()
{
    init_timer();
    wait_for_us(500);

    (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + 0x100)) = 0x00A00293;
    (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + 0x100 + 4)) = 0xFFF28293;
    (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + 0x100 + 8)) = 0xFE029EE3;
    (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + 0x100 + 12)) = 0x0000006F;

    /*
    unsigned int address = 0x00000000;
    unsigned int data_4bytes = 0;
    while(data_4bytes != 0xFFFFFFFF) {
        data_4bytes = (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + address));
        //if(data_4bytes == 0xFFFFFFFF) break;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data_4bytes;
        address += 4;
    }
    */
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        "li    t0, 0x80000000 \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

//void (*jump_to_dram)(void) = (void (*)(void))0x80000100;
static inline void jump_to_dram()
{
    //asm volatile ("j 0x80000100");
    asm volatile (
        "lui   t0, 0x80000 \n"
        "addi  t0, t0, 0x100 \n"
        "jalr  x0, t0, 0 \n"
    );
}

int main()
{
    load_code_through_dram();
    update_trap_vector_base_address();
    //jump_to_loaded_software();
    jump_to_dram();
    return 0;
}
