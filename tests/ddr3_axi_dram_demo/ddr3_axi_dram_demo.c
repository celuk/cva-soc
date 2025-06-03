#include "defines.h"
#include "uart.h"
#include "timer.h"
#include "dram.h"

#define DDR3_AXI_BASE_ADDR 0x80000000

void write_to_ddr3(unsigned int offset_in_ddr, unsigned int data) {
    (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + offset_in_ddr)) = data;
}

unsigned int read_from_ddr3(unsigned int offset_in_ddr) {
    return (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + offset_in_ddr));
}

int main()
{
    init_uart();
    init_timer();
    wait_for_us(500);

    write_to_ddr3(0x100, 0x1241BAEF);
    write_to_ddr3(0x200, 0x1241BEEF);
    write_to_ddr3(0x300, 0x1242BAEF);

    tekno_printf("Value read: %x\n", read_from_ddr3(0x200));

    return 0;
}