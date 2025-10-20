#include "uart.h"
#include "defines.h"

int main()
{
    char received_char;

    init_uart();
    
    tekno_printf("UART RX Test. Send characters from your terminal.\n");
    tekno_printf("Send '1' for Command 1.\n");
    tekno_printf("Send '2' for Command 2.\n");
    tekno_printf("Any other character will be echoed back.\n");

    while (1) {
        received_char = zgetchar();

        if (received_char == '1') {
            tekno_printf("Command 1 received!\n");
        } else if (received_char == '2') {
            tekno_printf("Command 2 received!\n");
        } else {
            //tekno_printf("Echo: ");
            zputchar(received_char);
            //tekno_printf("\n");
        }
    }

    return 0;
}
