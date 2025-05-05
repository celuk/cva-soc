#include "uart.h"
#include "defines.h"
//#include "core_portme.h"

int main()
{
    init_uart();
    
    print("Hello\n");
    return 0;
}
