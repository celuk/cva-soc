#include "qspi.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

int main(){
    init_uart();
    tekno_printf("QSPI read started\n");

    qspi_init();
    qspi_enable_quad_mode();

    unsigned int address = 0x00000000;
    unsigned int* data;
    for (unsigned int i = 0; i < 3000; i += 32) {
        data = qspi_read_qor(address);

        tekno_printf("DR0: %x\n", data[0]);
        tekno_printf("DR1: %x\n", data[1]);
        tekno_printf("DR2: %x\n", data[2]);
        tekno_printf("DR3: %x\n", data[3]);
        tekno_printf("DR4: %x\n", data[4]);
        tekno_printf("DR5: %x\n", data[5]);
        tekno_printf("DR6: %x\n", data[6]);
        tekno_printf("DR7: %x\n", data[7]);

        if(data[0] == 0xFFFFFFFF) {
            break;
        }

        if(data[1] == 0xFFFFFFFF) {
            break;
        }

        if(data[2] == 0xFFFFFFFF) {
            break;
        }

        if(data[3] == 0xFFFFFFFF) {
            break;
        }

        if(data[4] == 0xFFFFFFFF) {
            break;
        }

        if(data[5] == 0xFFFFFFFF) {
            break;
        }

        if(data[6] == 0xFFFFFFFF) {
            break;
        }

        if(data[7] == 0xFFFFFFFF) {
            break;
        }
        address += 32;
    }

}
