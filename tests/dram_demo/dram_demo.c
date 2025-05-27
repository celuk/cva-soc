#include "uart.h"
#include "dram.h"
#include "core_portme.h"

unsigned int addresses[8][8] =
{
    {0x00000001, 0x00000015, 0x0000001a, 0x0000001f, 0x00000024, 0x00000029, 0x0000002e, 0x00000033},
    {0x00000510, 0x00000515, 0x0000051a, 0x0000051f, 0x00000524, 0x00000529, 0x0000052e, 0x00000533},
    {0x00000a10, 0x00000a15, 0x00000a1a, 0x00000a1f, 0x00000a24, 0x00000a29, 0x00000a2e, 0x00000a33},
    {0x00000f10, 0x00000f15, 0x00000f1a, 0x00000f1f, 0x00000f24, 0x00000f29, 0x00000f2e, 0x00000f33},
    {0x00001410, 0x00001415, 0x0000141a, 0x0000141f, 0x00001424, 0x00001429, 0x0000142e, 0x00001433},
    {0x00001910, 0x00001915, 0x0000191a, 0x0000191f, 0x00001924, 0x00001929, 0x0000192e, 0x00001933},
    {0x00001e10, 0x00001e15, 0x00001e1a, 0x00001e1f, 0x00001e24, 0x00001e29, 0x00001e2e, 0x00001e33},
    {0x00002310, 0x00002315, 0x0000231a, 0x0000231f, 0x00002324, 0x00002329, 0x0000232e, 0x00002333}
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
