#include <stdint.h>
#include "timer.h"

#define CODE_RAM_BASE_ADDR 0x00002000
#define CODE_RAM (*(volatile uint32_t*) (CODE_RAM_BASE_ADDR))

void init()
{
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
    update_trap_vector_base_address();
    jump_to_dram();
    return 0;
}
