#ifndef DEFINES_H
#define DEFINES_H

#define CPU_MHZ 50
#define CPU_CLK (CPU_MHZ * 1000000)
#define BAUD_RATE 115200

#define US(x) (CPU_CLK/1000000 * x)

#endif
