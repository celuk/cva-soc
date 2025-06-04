#include "defines.h"
#include "uart.h"
#include "timer.h"

#define DDR3_AXI_BASE_ADDR 0x80000000

int main()
{
    init_uart();
    init_timer();
    wait_for_us(500);

    unsigned int address = 0x00000000;
    unsigned int data_4bytes = 0;
    while(data_4bytes != 0xFFFFFFFF) {
        data_4bytes = (*(volatile unsigned int*)(DDR3_AXI_BASE_ADDR + address));
        tekno_printf("Read data %x at address: %x\n", data_4bytes, address);
        address += 4;
    }

    return 0;
}
