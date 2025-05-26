#define DDR_BASE_ADDR 0x80000000

#include "uart.h"
#include "timer.h"
#include "defines.h"

#define DDR100 (*(volatile uint32_t*)(DDR_BASE_ADDR + 0x100))
#define DDR200 (*(volatile uint32_t*)(DDR_BASE_ADDR + 0x100))
#define DDR300 (*(volatile uint32_t*)(DDR_BASE_ADDR + 0x100))

void write_to_ddr3(unsigned int offset_in_ddr, unsigned int data) {
    volatile unsigned int* ptr = (*(volatile uint32_t*)(DDR_BASE_ADDR + offset_in_ddr));
    *ptr = data;
}

unsigned int read_from_ddr3(unsigned int offset_in_ddr) {
    volatile unsigned int* ptr = (*(volatile uint32_t*)(DDR_BASE_ADDR + offset_in_ddr));
    return *ptr;
}

int main() {
    init_uart();
    wait_for_us(500);

    //write_to_ddr3(0x100, 0x1241BAEF);
    //write_to_ddr3(0x200, 0x1241BEEF);
    //write_to_ddr3(0x300, 0x1242BAEF);

    DDR100 = 0x1241BAEF;
    DDR200 = 0x1241BEEF;
    DDR300 = 0x1242BAEF;

    unsigned int value = DDR200; //read_from_ddr3(0x100);

    tekno_printf("Value read from dram: %x\n", value);

    return 0;
}
