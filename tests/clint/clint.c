#include "clint.h"

int main() {
    volatile uint32_t msip_val;
    volatile uint32_t mtimecmp_low_val, mtimecmp_high_val;
    volatile uint32_t mtime_low_val_before, mtime_high_val_before;
    volatile uint32_t mtime_low_val_after, mtime_high_val_after;
    volatile uint32_t temp_high;

    CLINT_MSIP = 1;
    msip_val = CLINT_MSIP;
    CLINT_MSIP = 0;
    msip_val = CLINT_MSIP;

    do {
        mtime_high_val_before = CLINT_MTIME_HIGH;
        mtime_low_val_before = CLINT_MTIME_LOW;
        temp_high = CLINT_MTIME_HIGH;
    } while (mtime_high_val_before != temp_high);

    do {
        mtime_high_val_after = CLINT_MTIME_HIGH;
        mtime_low_val_after = CLINT_MTIME_LOW;
        temp_high = CLINT_MTIME_HIGH;
    } while (mtime_high_val_after != temp_high);

    uint64_t test_compare_val = 0x11223344AABBCCDD;

    CLINT_MTIMECMP_HIGH = 0xFFFFFFFF;
    CLINT_MTIMECMP_LOW = (uint32_t)test_compare_val;
    CLINT_MTIMECMP_HIGH = (uint32_t)(test_compare_val >> 32);

    mtimecmp_low_val = CLINT_MTIMECMP_LOW;
    mtimecmp_high_val = CLINT_MTIMECMP_HIGH;
    
    return 0;
}
