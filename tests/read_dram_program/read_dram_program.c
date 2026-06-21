#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

int main(){
    init_uart();
    tekno_printf("DRAM read started\n");

    init_timer();

    wait_for_us(500);

    unsigned int address = 0x80000000;
    unsigned int data_read;
    //while(data_read != 0xFFFFFFFF) {
    for (unsigned int i = 0; i < 980; i += 1) { // 7218*4 = 28872
        //unsigned int *data_16bytes = dram_read_16bytes(address);
        data_read = *((volatile unsigned int*)(address));
        //tekno_printf("Read data %x at address: %x\n", data_read, address);
        tekno_printf("%x\n", data_read);
        //if(data_read == 0xFFFFFFFF) break;
        address += 4;
    }
}
