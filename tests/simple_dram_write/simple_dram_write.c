static const unsigned int start_address = 0x00000000;

static const unsigned int data[] = {
    0x00A00293,
    0xFFF28293,
    0xFE029EE3,
    0x0000006F
};

#define DDR3_AXI_BASE_ADDR 0x80000000
#define DDR3_AXI_CODE_BASE_ADDR (DDR3_AXI_BASE_ADDR + 0x100)

int main()
{
    for (int i = 0; i < sizeof(data)/sizeof(data[0]); i++) {
        //(*((volatile unsigned int*)(DDR3_AXI_BASE_ADDR + start_address + i*4))) = data[i];
        *((volatile unsigned int*)(DDR3_AXI_CODE_BASE_ADDR + start_address + i*4)) = data[i];
        *((volatile unsigned int*)(DDR3_AXI_CODE_BASE_ADDR + 0x300 + start_address + i*4)) = data[i];
    }

    //init_uart();
    //print("Done");
    
    return 0;
}
