#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

int main(){
    init_uart();
    tekno_printf("DRAM read started\n");

    wait_for_us(500);

    unsigned int address = 0x00000000;
    for (unsigned int i = 0; i < 6277; i += 1) { // 7218*4 = 28872
        unsigned int *data_16bytes = dram_read_16bytes(address);
        tekno_printf("Read data %x at address: %x\n", data_16bytes[0], address);
        address += 4;
        tekno_printf("Read data %x at address: %x\n", data_16bytes[1], address);
        address += 4;
        tekno_printf("Read data %x at address: %x\n", data_16bytes[2], address);
        address += 4;
        tekno_printf("Read data %x at address: %x\n", data_16bytes[3], address);
        address += 4;
        //address += 4*4;
    }
}
