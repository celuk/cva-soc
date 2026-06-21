#include "uart.h"
#include "defines.h"

int main()
{
    init_uart();
    
    tekno_printf("hello\n");

    return 0;
}
