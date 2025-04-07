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
    for (unsigned int i = 0; i < 30000; i += 32) { // 7218*4 = 28872
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

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_ADR = 0x00001c00;
    qspi_set_ccr(
        /*inst_value*/       CMD_SE,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_DR0 = 0xbbbbbbbb;
    QSPI_DR1 = 0xbbbbbbbb;
    QSPI_DR2 = 0xbbbbbbbb;
    QSPI_DR3 = 0xbbbbbbbb;
    QSPI_DR4 = 0xbbbbbbbb;
    QSPI_DR5 = 0xbbbbbbbb;
    QSPI_DR6 = 0xbbbbbbbb;
    QSPI_DR7 = 0xbbbbbbbb;

    QSPI_ADR = 0x00001c00;
    qspi_set_ccr(
        /*inst_value*/       CMD_QPP,
        /*data_mod*/         3,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    data = qspi_read_qor(0x00001c00);

    tekno_printf("DR0: %x\n", data[0]);
    tekno_printf("DR1: %x\n", data[1]);
    tekno_printf("DR2: %x\n", data[2]);
    tekno_printf("DR3: %x\n", data[3]);
    tekno_printf("DR4: %x\n", data[4]);
    tekno_printf("DR5: %x\n", data[5]);
    tekno_printf("DR6: %x\n", data[6]);
    tekno_printf("DR7: %x\n", data[7]);

}
