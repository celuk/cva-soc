#include <stdint.h>
#include "clint.h"

#define CSR_MSTATUS             0x300
#define CSR_MIE                 0x304
#define CSR_MTVEC               0x305
#define CSR_MCAUSE              0x342

#define MSTATUS_MIE_BIT         (1 << 3)
#define MIE_MTIE_BIT            (1 << 7)
#define MCAUSE_INTERRUPT_MASK   0x80000000
#define MCAUSE_CODE_MASK        0x7FFFFFFF
#define MCAUSE_MACHINE_TIMER    7

static inline void csr_write(uint32_t csr, uint32_t val) {
    __asm__ volatile("csrw %0, %1" : : "i"(csr), "r"(val));
}

static inline uint32_t csr_read(uint32_t csr) {
    uint32_t result;
    __asm__ volatile("csrr %0, %1" : "=r"(result) : "i"(csr));
    return result;
}

volatile uint32_t interrupt_fired = 0;

void __attribute__((interrupt)) trap_handler(void) {
    uint32_t cause = csr_read(CSR_MCAUSE);

    if ((cause & MCAUSE_INTERRUPT_MASK) && ((cause & MCAUSE_CODE_MASK) == MCAUSE_MACHINE_TIMER)) {
        interrupt_fired = 1;
        CLINT_MTIMECMP_HIGH = 0xFFFFFFFF;
        CLINT_MTIMECMP_LOW  = 0xFFFFFFFF;
    }
}

void test_timer_interrupt(void) {
    uint32_t time_high, time_low;
    uint64_t current_time;
    uint64_t target_time;

    csr_write(CSR_MTVEC, (uint32_t)trap_handler);
    csr_write(CSR_MIE, csr_read(CSR_MIE) | MIE_MTIE_BIT);
    csr_write(CSR_MSTATUS, csr_read(CSR_MSTATUS) | MSTATUS_MIE_BIT);

    do {
        time_high = CLINT_MTIME_HIGH;
        time_low  = CLINT_MTIME_LOW;
    } while (time_high != CLINT_MTIME_HIGH);
    current_time = ((uint64_t)time_high << 32) | time_low;

    target_time = current_time + 10000;

    CLINT_MTIMECMP_HIGH = 0xFFFFFFFF;
    CLINT_MTIMECMP_LOW  = (uint32_t)target_time;
    CLINT_MTIMECMP_HIGH = (uint32_t)(target_time >> 32);

    __asm__ volatile ("wfi");

    csr_write(CSR_MSTATUS, csr_read(CSR_MSTATUS) & ~MSTATUS_MIE_BIT);

    while (1) {
    }
}

int main() {
    test_timer_interrupt();
    return 0;
}
