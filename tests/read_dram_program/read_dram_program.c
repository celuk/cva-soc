#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

int main(){
    init_uart();
    tekno_printf("DRAM read started\n");

    wait_for_us(500);

    unsigned int address = 0x00000000;
    for (unsigned int i = 0; i < 30000; i += 32) { // 7218*4 = 28872
        tekno_printf("Read data %x at address: %x\n", dram_read(address), address);
        address += 4;
    }
}
