#include "qspi.h"
#include "timer.h"
#include "defines.h"

void qspi_init(){
    wait_for_us(500);
    //wait_for_us(10);
}

void qspi_set_ccr(unsigned int inst_value, unsigned int data_mod, unsigned int wr_flash, unsigned int dummy_cycle, unsigned int data_size, unsigned int prescaler, unsigned int clear_status_reg){
    qspi_ccr ccr;
    ccr.fields.inst_value = inst_value;
    ccr.fields.data_mod = data_mod;
    ccr.fields.wr_flash = wr_flash;
    ccr.fields.dummy_cycle = dummy_cycle;
    ccr.fields.data_size = data_size;
    ccr.fields.prescaler = prescaler;
    ccr.fields.clear_status_reg = clear_status_reg;
    QSPI_CCR = ccr.bits;
}

void wait_for_not_busy() {
    qspi_sta sta;
    do {
        sta.bits = QSPI_STA;
    } while (sta.fields.busy);
}

unsigned int read_status_register(unsigned int cmd) {
    qspi_ccr ccr;
    ccr.fields.inst_value = cmd;
    ccr.fields.data_mod = 1;
    ccr.fields.wr_flash = 0;
    ccr.fields.dummy_cycle = 0;
    ccr.fields.data_size = 0;
    ccr.fields.prescaler = 1;
    ccr.fields.clear_status_reg = 0;
    
    QSPI_CCR = ccr.bits;
    wait_for_not_busy();
    
    return (unsigned int)QSPI_DR0;
}

// if wel is not set, wait
void wait_for_wel_set() {
    while (!(read_status_register(CMD_RDSR1) & 0x02));
}

void wait_for_wel_down() {
    while (read_status_register(CMD_RDSR1) & 0x02);
}

// if write in progress, wait
void wait_for_wip_done() {
    while (read_status_register(CMD_RDSR1) & 0x01);
}

void qspi_enable_quad_mode(){
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

    // 8bit CR | 8bit SR
    QSPI_DR0 = 0x00000200; // CR[1] = 1 for quad mode
    qspi_set_ccr(
        /*inst_value*/       CMD_WRR,
        /*data_mod*/         1,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        1, // SR + CR = 2 byte
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
}

void qspi_disable_quad_mode(){
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

    // 8bit CR | 8bit SR
    QSPI_DR0 = 0x00000000; // CR[1] = 0 for single and dual mode
    qspi_set_ccr(
        /*inst_value*/       CMD_WRR,
        /*data_mod*/         1,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        1, // SR + CR = 2 byte
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
}

uint32_t* qspi_read_qor(uint32_t address) {
    static uint32_t data[8];

    QSPI_ADR = address;
    qspi_set_ccr(
        /*inst_value*/       CMD_QOR,
        /*data_mod*/         3,
        /*wr_flash*/         0,
        /*dummy_cycle*/      8, // if below 50mhz it can be 0
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    data[0] = QSPI_DR0;
    data[1] = QSPI_DR1;
    data[2] = QSPI_DR2;
    data[3] = QSPI_DR3;
    data[4] = QSPI_DR4;
    data[5] = QSPI_DR5;
    data[6] = QSPI_DR6;
    data[7] = QSPI_DR7;

    return data;
}
