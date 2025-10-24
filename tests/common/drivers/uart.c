#include "uart.h"
#include "defines.h"

#ifndef USE_COREMARK_UTILS
#define RX_BUFFER_SIZE 64
static volatile char rx_buffer[RX_BUFFER_SIZE];
static volatile int rx_head = 0;
static volatile int rx_tail = 0;

void uart_enable_rx_irq()
{
    UART_CTRL |= UART_CTRL_RX_IRQ_EN;
}

void uart_disable_rx_irq()
{
    UART_CTRL &= ~UART_CTRL_RX_IRQ_EN;
}

void uart_isr()
{
    if (UART_STATUS & UART_STATUS_RX_FULL) {
        char received_char = (char)UART_RDATA;
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
    while (UART_STATUS & UART_STATUS_TX_FULL) {
    }
    UART_WDATA = c;
}

int strcmp(const char* p1, const char* p2)
{
    const unsigned char* s1 = (const unsigned char*)p1;
    const unsigned char* s2 = (const unsigned char*)p2;
    unsigned char c1, c2;
    do {
        c1 = (unsigned char)*s1++;
        c2 = (unsigned char)*s2++;
        if (c1 == '\0')
            return c1 - c2;
    } while (c1 == c2);
    return c1 - c2;
}

size_t strlen(const char* s)
{
    const char* p = s;
    while (*p)
        p++;
    return p - s;
}
#endif

void print(const char* p)
{
    while (*p)
        zputchar(*(p++));
}

void tekno_printf(const char* fmt, ...)
{
    va_list vl;
    bool is_format, is_long, is_char;
    char c, string_buf[11];

    va_start(vl, fmt);
    is_format = false;
    is_long = false;
    is_char = false;
    while ((c = *fmt++) != '\0') {
        if (is_format) {
            switch (c) {
            case 'l':
                is_long = true;
                is_format = true;
                is_char = false;
                continue;
            case 'h':
                is_char = true;
                is_format = false;
                is_long = false;
                continue;
            case 'f':
            case 'x': {
                unsigned long n;
                long i;
                if (is_long) {
                    n = va_arg(vl, unsigned long);
                    i = (sizeof(unsigned long) << 3) - 4;
                } else {
                    n = va_arg(vl, unsigned int);
                    i = is_char ? 4 : (sizeof(unsigned int) << 3) - 4;
                }
                for (; i >= 0; i -= 4) {
                    long d;
                    d = (n >> i) & 0xF;
                    zputchar(d < 10 ? '0' + d : 'a' + d - 10);
                }
                is_format = false;
                is_long = false;
                is_char = false;
                break;
            }
            case 'd': {
                long num = is_long ? va_arg(vl, long) : va_arg(vl, int);
                if (num < 0) {
                    num = -num;
                    zputchar('-');
                }
                long digits = 1;
                char digit_array[20];
                for (long nn = num; nn /= 10; digits++)
                    ;
                for (int i = digits - 1; i >= 0; i--) {
                    digit_array[i] = '0' + (num % 10);
                    num /= 10;
                }
                for (int i = 0; i < digits; i++) {
                    zputchar(digit_array[i]);
                }
                is_format = false;
                is_long = false;
                is_char = false;
                break;
            }
            case 'u': {
                long unsigned num = is_long ? va_arg(vl, long) : va_arg(vl, int);
                long digits = 1;
                for (long nn = num; nn /= 10; digits++)
                    ;
                for (int i = digits - 1; i >= 0; i--) {
                    zputchar('0' + (num % 10));
                    num /= 10;
                }
                is_format = false;
                is_long = false;
                is_char = false;
                break;
            }
            case 's':
                print(va_arg(vl, const char*));
                is_format = false;
                is_long = false;
                is_char = false;
                break;
            case 'c':
                zputchar(va_arg(vl, int));
                is_format = false;
                is_long = false;
                is_char = false;
                break;
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                break;
            default:
                print("%");
                is_format = false;
                is_long = false;
                is_char = false;
                break;
            }
        } else if (c == '%') {
            is_format = true;
        } else {
            zputchar(c);
            if (c == '\n') {
                zputchar('\r');
            }
        }
    }
    va_end(vl);
}

int zscan(char* buffer, int max_size, int echo)
{
    char c = 0;
    int length = 0;

    while (1) {
        c = zgetchar();
        if (c == '\b') {
            if (length != 0) {
                if (echo) {
                    print("\b \b");
                }
                buffer--;
                length--;
            }
        } else if (c == '\r')
            break;
        else if ((c >= ' ') && (c <= '~') && (length < (max_size - 1))) {
            if (echo) {
                zputchar(c);
            }
            *buffer++ = c;
            length++;
        }
    }
    *buffer = '\0';
    print("\n");

    return length;
}

void init_uart()
{
    uint32_t baud_divisor = CPU_CLK / BAUD_RATE;
    UART_CTRL = (baud_divisor << 16) | UART_CTRL_TX_EN | UART_CTRL_RX_EN;
}
