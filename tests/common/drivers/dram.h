#ifndef DRAM_H
#define DRAM_H

#include <stdint.h>

#define DRAM_BASE_ADDR  0xFF070000
#define DRAM_COMMAND_OFFSET 0x00
#define DRAM_ADDRESS_OFFSET 0x04
#define DRAM_DATA_WRITE_OFFSET 0x08
#define DRAM_DATA_READ_OFFSET 0x0C
#define DRAM_TIMER_RESET_OFFSET 0x10
#define DRAM_TIMER_OFFSET 0x14
#define DRAM_RE_OFFSET 0x18
#define DRAM_WE_OFFSET 0x1C
#define DRAM_ACCEPT_OFFSET 0x20
#define DRAM_ACK_OFFSET 0x24
#define DRAM_PWRUP_OFFSET 0x28
#define DRAM_TRCD_OFFSET 0x30
#define DRAM_NONSEQ_OFFSET 0x34
#define DRAM_RWNONSEQ_OFFSET 0x38
#define DRAM_TRP_OFFSET 0x3C
#define DRAM_TRFC_OFFSET 0x40
#define DRAM_RWSEQ_OFFSET 0x44
#define DRAM_WDG_OFFSET 0x48

#define DRAM_COMMAND (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_COMMAND_OFFSET))
#define DRAM_ADDRESS (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_ADDRESS_OFFSET))
#define DRAM_DATA_WRITE (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_DATA_WRITE_OFFSET))
#define DRAM_DATA_READ (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_DATA_READ_OFFSET))
#define DRAM_TIMER_RESET (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_TIMER_RESET_OFFSET))
#define DRAM_TIMER (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_TIMER_OFFSET))
#define DRAM_RE (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_RE_OFFSET))
#define DRAM_WE (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_WE_OFFSET))
#define DRAM_ACCEPT (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_ACCEPT_OFFSET))
#define DRAM_ACK (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_ACK_OFFSET))
#define DRAM_PWRUP (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_PWRUP_OFFSET))
#define DRAM_TRCD (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_TRCD_OFFSET))
#define DRAM_NONSEQ (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_NONSEQ_OFFSET))
#define DRAM_RWNONSEQ (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_RWNONSEQ_OFFSET))
#define DRAM_TRP (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_TRP_OFFSET))
#define DRAM_TRFC (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_TRFC_OFFSET))
#define DRAM_RWSEQ (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_RWSEQ_OFFSET))
#define DRAM_WDG (*(volatile uint32_t*) (DRAM_BASE_ADDR + DRAM_WDG_OFFSET))

typedef union
{
	struct {
		unsigned int rst_n : 1;
		unsigned int cke   : 1;
		unsigned int cs_n  : 1;
		unsigned int ras_n : 1;
        unsigned int cas_n : 1;
        unsigned int we_n  : 1;
        unsigned int a12   : 1;
        unsigned int a10   : 1;
	} fields;
	uint32_t bits;
} command_t;

void init_dram(unsigned int wait_time);
void set_dram_address(uint32_t address);
void write_dram_data(uint32_t data);
uint32_t read_dram_data();
void set_dram_timer_reset(uint32_t reset);
uint32_t get_dram_timer();
void wait_for_dram(unsigned int time);
void dram_write(unsigned int address, unsigned int data);
unsigned int dram_read(unsigned int address);
void set_dram_commands(command_t commands);

#endif
