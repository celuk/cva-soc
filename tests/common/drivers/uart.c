#include "uart.h"
#include "defines.h"

#ifndef USE_COREMARK_UTILS
int uart_txfull()
{
    // __asm__ volatile("fence" ::: "memory");
    while ((UART_CFG & 0x4) == 0) { }
    // __asm__ volatile("fence" ::: "memory");
}

void zputchar(char c)
{
    uart_txfull();

    // __asm__ volatile("fence" ::: "memory");
    // TX complete bitini temizle
    UART_CFG &= ~0x4;
    // __asm__ volatile("fence" ::: "memory");
    // Veriyi gönder
    UART_TDR = c;
    // __asm__ volatile("fence" ::: "memory");
    // TX enable bitini set et
    UART_CFG = UART_CFG | 0x1;
    // __asm__ volatile("fence" ::: "memory");

    // TX tamamlanana kadar bekle
    uart_txfull();
}
#endif

//-----------------------------------------------
// print a string (char*).
//-----------------------------------------------

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
                // print(" unknown instruction ");
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

//-----------------------------------------------
// scan a single character.
//-----------------------------------------------

int uart_rxempty()
{
    // __asm__ volatile("fence" ::: "memory");
    return (UART_CFG & 0x2) == 0; // RX complete biti kontrol ediliyor
}

char zgetchar()
{
    // Veri gelene kadar bekle
    while (uart_rxempty()) {
        // Bekle
    }
    // __asm__ volatile("fence" ::: "memory");
    char c = (char)UART_RDR;

    // RX complete bitini temizle
    // __asm__ volatile("fence" ::: "memory");
    UART_CFG &= ~0x2;
    // __asm__ volatile("fence" ::: "memory");

    return c;
}
//-----------------------------------------------
// scan multiple characters.
//-----------------------------------------------

int zscan(char* buffer, int max_size, int echo)
{
    char c = 0;
    int length = 0;

    while (1) {
        c = zgetchar();
        if (c == '\b') { // BACKSPACE
            if (length != 0) {
                if (echo) {
                    print("\b \b"); // delete last char in console
                }
                buffer--;
                length--;
            }
        } else if (c == '\r') // carriage return
            break;
        else if ((c >= ' ') && (c <= '~') && (length < (max_size - 1))) {
            if (echo) {
                zputchar(c); // echo
            }
            *buffer++ = c;
            length++;
        }
    }
    *buffer = '\0'; // terminate string
    print("\n");

    return length;
}

#ifndef USE_COREMARK_UTILS
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

void init_uart()
{
    uart_cpb uart_cpb;
    uart_cpb.fields.data = CPU_CLK / BAUD_RATE;
    // TX enable bitini set et

    // __asm__ volatile("fence" ::: "memory");
    UART_CFG = UART_CFG | 0x7;
    // __asm__ volatile("fence" ::: "memory");
    UART_CPB = uart_cpb.bits;
    // __asm__ volatile("fence" ::: "memory");
    UART_STP = UART_STP | 0x1;
    // __asm__ volatile("fence" ::: "memory");
}
