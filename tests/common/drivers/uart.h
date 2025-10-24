#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>

#define UART_CTRL       (*(volatile uint32_t*)0xFF000000)
#define UART_STATUS     (*(volatile uint32_t*)0xFF000004)
#define UART_RDATA      (*(volatile uint32_t*)0xFF000008)
#define UART_WDATA      (*(volatile uint32_t*)0xFF00000c)

void     tekno_printf    (const char *fmt, ...);
void     print           (const char *p);
int      zscan           (char *buffer, int max_size, int echo);
char     zgetchar        ();
void     zputchar        (char c);
int      strcmp          (const char *p1, const char *p2);
size_t   strlen          (const char *s);
int 	 uart_txfull	 ();
int 	 uart_rxempty	 ();
void init_uart();

typedef union
{
	struct {
		unsigned int tx_en    : 1;
		unsigned int rx_en 	  : 1;
		unsigned int null	  : 14;
		unsigned int baud_div : 16;
	} fields;
	uint32_t bits;
}uart_ctrl;

typedef union
{
	struct {
		unsigned int tx_full  : 1;
		unsigned int rx_full  : 1;
		unsigned int tx_empty : 1;
		unsigned int rx_empty : 1;
		unsigned int null	  : 28;
	} fields;
	uint32_t bits;
}uart_status;

#endif
