#include "uart.h"
#include "defines.h"

#ifndef USE_COREMARK_UTILS
#define RX_BUFFER_SIZE 64
static volatile char rx_buffer[RX_BUFFER_SIZE];
static volatile int rx_head = 0;
static volatile int rx_tail = 0;

void uart_enable_rx_irq()
{
    UART_CFG |= UART_CFG_RX_IRQ_EN_BIT;
}

void uart_disable_rx_irq()
{
    UART_CFG &= ~UART_CFG_RX_IRQ_EN_BIT;
}

void uart_isr()
{
    if (UART_CFG & UART_CFG_RX_FULL_BIT) {
        char received_char = (char)UART_RDR;
        int next_head = (rx_head + 1) % RX_BUFFER_SIZE;
        if (next_head != rx_tail) {
            rx_buffer[rx_head] = received_char;
            rx_head = next_head;
        }
    }
}

char zgetchar()
{
    while (rx_head == rx_tail) {
    }

    char c = rx_buffer[rx_tail];
    rx_tail = (rx_tail + 1) % RX_BUFFER_SIZE;
    return c;
}

void zputchar(char c)
{
    while (UART_CFG & UART_CFG_TX_FULL_BIT) {
    }
    UART_TDR = c;
}

void print(const char* p)
{
    while (*p) {
        zputchar(*(p++));
    }
}

void tekno_printf(const char* fmt, ...) {
    // This function can remain the same as your original
    va_list vl;
    bool is_format, is_long, is_char;
    char c;
    va_start(vl, fmt);
    is_format = false;
    is_long = false;
    is_char = false;
    while ((c = *fmt++) != '\0') {
        if (is_format) {
            switch (c) {
                case 'l': is_long = true; is_format = true; is_char = false; continue;
                case 'h': is_char = true; is_format = false; is_long = false; continue;
                case 'x': {
                    unsigned long n; long i;
                    if (is_long) { n = va_arg(vl, unsigned long); i = (sizeof(unsigned long) << 3) - 4; }
                    else { n = va_arg(vl, unsigned int); i = is_char ? 4 : (sizeof(unsigned int) << 3) - 4; }
                    for (; i >= 0; i -= 4) { long d = (n >> i) & 0xF; zputchar(d < 10 ? '0' + d : 'a' + d - 10); }
                    is_format = false; is_long = false; is_char = false;
                    break;
                }
                case 's': print(va_arg(vl, const char*)); is_format = false; is_long = false; is_char = false; break;
                case 'c': zputchar(va_arg(vl, int)); is_format = false; is_long = false; is_char = false; break;
                default: is_format = false; is_long = false; is_char = false; break;
            }
        } else if (c == '%') {
            is_format = true;
        } else {
            zputchar(c);
        }
    }
    va_end(vl);
}
#endif

void init_uart()
{
    uart_cpb uart_cpb;
    uart_cpb.fields.data = CPU_CLK / BAUD_RATE;
    UART_CPB = uart_cpb.bits;
    UART_STP = 1;
    UART_CFG = UART_CFG_TX_EN_BIT;
    uart_enable_rx_irq();
}
