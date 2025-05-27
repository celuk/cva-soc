#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

int main(){
    init_uart();
    tekno_printf("DRAM read started\n");

    wait_for_us(500);

    unsigned int address = 0x00000000;
    unsigned int data_16bytes[4];
    while(data_16bytes[4] != 0xFFFFFFFF) {
    //for (unsigned int i = 0; i < 1569; i += 1) { // 7218*4 = 28872
        //unsigned int *data_16bytes = dram_read_16bytes(address);
        dram_read_16bytes(address, data_16bytes);
        tekno_printf("Read data %x at address: %x\n", data_16bytes[0], address);
        if(data_16bytes[0] == 0xFFFFFFFF) break;
        address += 4;
        tekno_printf("Read data %x at address: %x\n", data_16bytes[1], address);
        if(data_16bytes[1] == 0xFFFFFFFF) break;
        address += 4;
        tekno_printf("Read data %x at address: %x\n", data_16bytes[2], address);
        if(data_16bytes[2] == 0xFFFFFFFF) break;
        address += 4;
        tekno_printf("Read data %x at address: %x\n", data_16bytes[3], address);
        if(data_16bytes[3] == 0xFFFFFFFF) break;
        address += 4;
        //address += 4*4;
    }
}
