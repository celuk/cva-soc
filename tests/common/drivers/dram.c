#include "dram.h"
#include "defines.h"

void init_dram(unsigned int wait_time){
    wait_for_dram(US(wait_time));
}

void set_dram_address(uint32_t address){
    DRAM_ADDRESS = address;
}

void write_dram_data(uint32_t data){
    DRAM_DATA_WRITE = data;
}

uint32_t read_dram_data(){
    return DRAM_DATA_READ;
}

void set_dram_timer_reset(uint32_t reset){
    DRAM_TIMER_RESET = reset;
}

uint32_t get_dram_timer(){
    return DRAM_TIMER;
}

void wait_for_dram(unsigned int time){
    set_dram_timer_reset(1);
    set_dram_timer_reset(0);
	unsigned int start = get_dram_timer();
	unsigned int end = get_dram_timer();
    unsigned int diff = end - start;
	while(((diff)) < time){
		end = get_dram_timer();
        if(end > start)
            diff = end - start;
        else
            diff = start - end;
	}
}

void dram_write(unsigned int address, unsigned int data){
    // order is important
    DRAM_ADDRESS = address;
    DRAM_DATA_WRITE = data;
    DRAM_WE = 1;
    while(!DRAM_ACCEPT);
    while(!DRAM_ACK);
}

unsigned int dram_read(unsigned int address){
    DRAM_ADDRESS = address;
    DRAM_RE = 1;
    while(!DRAM_ACCEPT);
    while(!DRAM_ACK);
    return DRAM_DATA_READ;
}

void dram_write_16bytes(unsigned int address, unsigned int data0, unsigned int data1, unsigned int data2, unsigned int data3){
    // order is important
    DRAM_ADDRESS = address;
    DRAM_DATA_WRITE = data0;
    DRAM_DATA_WRITE1 = data1;
    DRAM_DATA_WRITE2 = data2;
    DRAM_DATA_WRITE3 = data3;
    DRAM_WE = 1;
    while(!DRAM_ACCEPT);
    while(!DRAM_ACK);
}


// unsigned int *data_ptr = dram_read_16bytes(dram_address);
// unsigned int word0 = data_ptr[0];
// unsigned int word1 = data_ptr[1];
// unsigned int word2 = data_ptr[2];
// unsigned int word3 = data_ptr[3];
unsigned int* dram_read_16bytes(unsigned int address){
    unsigned int data_buffer[4];

    DRAM_ADDRESS = address;
    DRAM_RE = 1;
    while(!DRAM_ACCEPT);
    while(!DRAM_ACK);

    data_buffer[0] = DRAM_DATA_READ;
    data_buffer[1] = DRAM_DATA_READ1;
    data_buffer[2] = DRAM_DATA_READ2;
    data_buffer[3] = DRAM_DATA_READ3;
    
    return data_buffer;
}

void set_dram_commands(command_t commands){
    DRAM_COMMAND = commands.bits;
}

/*
void NOP(){
    command_t commands;
    commands.fields.rst_n = 0;
    commands.fields.cke = 1;
    commands.fields.cs_n = 0;
    commands.fields.ras_n = 1;
    commands.fields.cas_n = 1;
    commands.fields.we_n = 1;
    commands.fields.a12 = 0;
    commands.fields.a10 = 0;
    DRAM_COMMAND = commands.bits;
}
*/

/*
void NOP() {
    command_t commands = {.fields = {0, 1, 0, 1, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void NOPCKE0() {
    command_t commands = {.fields = {1, 0, 0, 1, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}
void NOPRSTN1() {
    command_t commands = {.fields = {1, 0, 0, 1, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}
void NOPRSTN1CKE1() {
    command_t commands = {.fields = {1, 1, 0, 1, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void PRE() {
    command_t commands = {.fields = {0, 1, 0, 0, 1, 0, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void PREA() {
    command_t commands = {.fields = {0, 1, 0, 0, 1, 0, 0, 1}};
    DRAM_COMMAND = commands.bits;
}

void REF() {
    command_t commands = {.fields = {0, 1, 0, 0, 0, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void ACT() {
    command_t commands = {.fields = {0, 1, 0, 0, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void WR() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void RD() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void WRITE_P() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 1, 0}};
    DRAM_COMMAND = commands.bits;
}

void READ_P() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 1, 0}};
    DRAM_COMMAND = commands.bits;
}

void WRAP() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 0, 1}};
    DRAM_COMMAND = commands.bits;
}

void RDAP() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 0, 1}};
    DRAM_COMMAND = commands.bits;
}

void MRS() {
    command_t commands = {.fields = {0, 1, 0, 0, 0, 0, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void WRS4() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void WRS8() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 1, 0}};
    DRAM_COMMAND = commands.bits;
}

void WRAPS4() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 0, 1}};
    DRAM_COMMAND = commands.bits;
}

void WRAPS8() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 0, 1, 1}};
    DRAM_COMMAND = commands.bits;
}

void RDS4() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void RDS8() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 1, 0}};
    DRAM_COMMAND = commands.bits;
}

void RDAPS4() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 0, 1}};
    DRAM_COMMAND = commands.bits;
}

void RDAPS8() {
    command_t commands = {.fields = {0, 1, 0, 1, 0, 1, 1, 1}};
    DRAM_COMMAND = commands.bits;
}

void PDE() {
    command_t commands = {.fields = {0, 1, 0, 1, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void PDX() {
    command_t commands = {.fields = {0, 1, 0, 1, 1, 1, 0, 0}};
    DRAM_COMMAND = commands.bits;
}

void ZQCL() {
    command_t commands = {.fields = {0, 1, 0, 1, 1, 0, 0, 1}};
    DRAM_COMMAND = commands.bits;
}

void ZQCS() {
    command_t commands = {.fields = {0, 1, 0, 1, 1, 0, 0, 0}};
    DRAM_COMMAND = commands.bits;
}
*/
