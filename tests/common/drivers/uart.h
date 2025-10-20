#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>

#define UART_CPB       (*(volatile uint32_t*)0xFF000000)
#define UART_STP       (*(volatile uint32_t*)0xFF000004)
#define UART_RDR       (*(volatile uint32_t*)0xFF000008)
#define UART_TDR       (*(volatile uint32_t*)0xFF00000c)
#define UART_CFG       (*(volatile uint32_t*)0xFF000010)

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
		unsigned int cfg_0    : 1;
		unsigned int cfg_1 	  : 1;
		unsigned int cfg_2 	  : 1;
		unsigned int null	  : 29;
	} fields;
	uint32_t bits;
}uart_cfg;

typedef union
{
	struct {
		unsigned int stp    : 2;
		unsigned int null	  : 30;
	} fields;
	uint32_t bits;
}uart_stp;

typedef union
{
	struct {
		unsigned int data    : 8;
		unsigned int null    : 24;
	} fields;
	uint32_t bits;
}uart_tdr;

typedef union
{
	struct {
		unsigned int data    : 8;
		unsigned int null    : 24;
	} fields;
	uint32_t bits;
}uart_rdr;

typedef union
{
	struct {
		unsigned int data    : 32;
	} fields;
	uint32_t bits;
}uart_cpb;

#endif
