#include "uart.h"
#include "dram.h"
#include "core_portme.h"

unsigned int addresses[8][8] =
{
    {0x00000000, 0x00000014, 0x0000001c, 0x0000001f, 0x00000028, 0x0000002c, 0x0000002f, 0x00000034},
    {0x00000510, 0x00000514, 0x0000051c, 0x0000051f, 0x00000528, 0x0000052c, 0x0000052f, 0x00000534},
    {0x00000a10, 0x00000a14, 0x00000a1c, 0x00000a1f, 0x00000a28, 0x00000a2c, 0x00000a2f, 0x00000a34},
    {0x00000f10, 0x00000f14, 0x00000f1c, 0x00000f1f, 0x00000f28, 0x00000f2c, 0x00000f2f, 0x00000f34},
    {0x00001410, 0x00001414, 0x0000141c, 0x0000141f, 0x00001428, 0x0000142c, 0x0000142f, 0x00001434},
    {0x00001910, 0x00001914, 0x0000191c, 0x0000191f, 0x00001928, 0x0000192c, 0x0000192f, 0x00001934},
    {0x00001e10, 0x00001e14, 0x00001e1c, 0x00001e1f, 0x00001e28, 0x00001e2c, 0x00001e2f, 0x00001e34},
    {0x00002310, 0x00002314, 0x0000231c, 0x0000231f, 0x00002328, 0x0000232c, 0x0000232f, 0x00002334}
};

int main()
{
    init_uart();
    init_dram(500);

    unsigned int address = 0x00002FFF;
    unsigned int data = 0x1234BAEF;
    dram_write(address, data);
    ee_printf("basladi");
    dram_write(0x00001FFF, 0x1234BEEF);
    dram_read(address);

    dram_write(0x00001FFF, 0xab1cd2ef);
    dram_write(0x0000100F, 0xed2f3abd);

    ee_printf("data: %x\n", dram_read(0x00001FFF));
    ee_printf("data: %x\n", dram_read(0x0000100F));
    ee_printf("data: %x\n", dram_read(address));

    ee_printf("bitti\n");

    ee_printf("Basladi..\n");
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            address = addresses[i][j];
            //ee_printf("%d\n", address);
            dram_write(address, 0x1234BEEF);
            //ee_printf("%d\n", i*j);
        }
    }

    int error_count = 0;
    int value = 0;
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 4; j++) {
            address = addresses[i][j];
            //ee_printf("0x%x\n", dram_read(address));
            value = dram_read(address);
            ee_printf("0x%x\n", value);
            if (value != 0x1234BEEF) {
                error_count++;
            }
        }
    }
    ee_printf("Error count: %d\n", error_count);
    
    return 0;
}
