#include <stdint.h>
#include "timer.h"

#define CODE_RAM_BASE_ADDR 0x00002000
#define CODE_RAM (*(volatile uint32_t*) (CODE_RAM_BASE_ADDR))

#define DDR3_AXI_BASE_ADDR 0x80000000

void load_code_through_dram()
{
    init_timer();
    wait_for_us(500);

    unsigned int address = 0x00000000;
    unsigned int data_4bytes = 0;
    while(data_4bytes != 0xFFFFFFFF) {
        data_4bytes = (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + address));
        //if(data_4bytes == 0xFFFFFFFF) break;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data_4bytes;
        address += 4;
    }
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        "li    t0, 0x2000    \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

static inline void jump_to_loaded_software()
{
    asm volatile ("j 0x2100");
}

int main()
{
    load_code_through_dram();
    update_trap_vector_base_address();
    jump_to_loaded_software();
    return 0;
}
