#include <stdint.h>
#include "dram.h"
#include "timer.h"

#define CODE_RAM_BASE_ADDR 0x00002000 //0x00010000
#define CODE_RAM (*(volatile uint32_t*) (CODE_RAM_BASE_ADDR))

void load_code_through_dram()
{
    init_timer();
    wait_for_us(500);

    unsigned int address = 0x00000000;
    unsigned int data_16bytes[4];
    while(data_16bytes[4] != 0xFFFFFFFF) {
    //for (unsigned int i = 0; i < 1569; i += 1) { // 7218*4 = 28872
        //unsigned int *data_16bytes = dram_read_16bytes(address);
        dram_read_16bytes(address, data_16bytes);
        //tekno_printf("Read data %x at address: %x\n", data_16bytes[0], address);
        if(data_16bytes[0] == 0xFFFFFFFF) break;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data_16bytes[0];
        address += 4;
        //tekno_printf("Read data %x at address: %x\n", data_16bytes[1], address);
        if(data_16bytes[1] == 0xFFFFFFFF) break;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data_16bytes[1];
        address += 4;
        //tekno_printf("Read data %x at address: %x\n", data_16bytes[2], address);
        if(data_16bytes[2] == 0xFFFFFFFF) break;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data_16bytes[2];
        address += 4;
        //tekno_printf("Read data %x at address: %x\n", data_16bytes[3], address);
        if(data_16bytes[3] == 0xFFFFFFFF) break;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data_16bytes[3];
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
