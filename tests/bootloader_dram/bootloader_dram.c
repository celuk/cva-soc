#include <stdint.h>
#include "timer.h"

void init()
{
    init_timer();
    wait_for_us(1000);
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
        "lui   t0, 0x80002 \n"
        "addi  t0, t0, 0x0 \n"
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
