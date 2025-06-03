static const unsigned int addresses[] = {
    0x3F029B1A, 0x35029B1D
};

static const unsigned int data[] = {
    0x1241BAEF, 0x2231BEEF
};

#define CPU_MHZ 100
#define CPU_CLK (CPU_MHZ * 1000000)
#define BAUD_RATE 115200

#define US(x) (CPU_CLK/1000000 * x)

#define TIM_BASE_ADDR  0xFF050000
#define TIM_PRE_OFFSET 0x00
#define TIM_ARE_OFFSET 0x04
#define TIM_CLR_OFFSET 0x08
#define TIM_ENA_OFFSET 0x0C
#define TIM_MOD_OFFSET 0x10
#define TIM_CNT_OFFSET 0x14
#define TIM_EVC_OFFSET 0x1C

#define TIM_PRE (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_PRE_OFFSET))
#define TIM_ARE (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_ARE_OFFSET))
#define TIM_CLR (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_CLR_OFFSET))
#define TIM_ENA (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_ENA_OFFSET))
#define TIM_MOD (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_MOD_OFFSET))
#define TIM_CNT (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_CNT_OFFSET))
#define TIM_EVC (*(volatile unsigned int*) (TIM_BASE_ADDR + TIM_EVC_OFFSET))

#define DDR3_AXI_BASE_ADDR 0x80000000

int main()
{
    // init timer
    TIM_CLR = 1;
    TIM_EVC = 1;
    TIM_PRE = 0;
    TIM_ARE = 0xFFFFFFFF;
    TIM_ENA = 1;
    TIM_MOD = 1;
    TIM_EVC = 0;
    TIM_CLR = 0;

    // wait for 500 us
    unsigned int start = TIM_CNT;
	unsigned int end = TIM_CNT;
    unsigned int diff = end - start;
	while(((diff)) < US(500)){
		end = TIM_CNT;
        if(end > start)
            diff = end - start;
        else
            diff = start - end;
	}

    for (int i = 0; i < sizeof(addresses)/sizeof(addresses[0]); i++) {
        (*(volatile unsigned int*)(DDR3_AXI_BASE_ADDR + addresses[i])) = data[i];
    }
    
    return 0;
}
