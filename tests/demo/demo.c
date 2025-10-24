#include "uart.h"
#include "defines.h"

// --- CSR Addresses and Bitmasks ---
#define CSR_MSTATUS             0x300
#define CSR_MIE                 0x304
#define CSR_MCAUSE              0x342

#define MSTATUS_MIE_BIT         (1 << 3)
#define MIE_MEIE_BIT            (1 << 11)

#define MCAUSE_INT_MASK         0x80000000
#define MCAUSE_CODE_MASK        0x7FFFFFFF
#define MCAUSE_MACHINE_EXT_INT  11

// --- PLIC Register Definitions ---
#define PLIC_BASE_ADDR          0xFC000000
#define PLIC_PRIORITY_BASE      (PLIC_BASE_ADDR + 0x0)
#define PLIC_ENABLE_BASE        (PLIC_BASE_ADDR + 0x2000)
#define PLIC_THRESHOLD_BASE     (PLIC_BASE_ADDR + 0x200000)
#define PLIC_CLAIM_BASE         (PLIC_BASE_ADDR + 0x200004)

#define UART_IRQ_SOURCE_ID      1

// --- Inline Assembly for CSR access ---
static inline void csr_write(uint32_t csr, uint32_t val) {
    __asm__ volatile("csrw %0, %1" : : "i"(csr), "r"(val));
}
static inline uint32_t csr_read(uint32_t csr) {
    uint32_t result;
    __asm__ volatile("csrr %0, %1" : "=r"(result) : "i"(csr));
    return result;
}

extern void exc_wrapper();

void exception_handler(uint32_t mcause, uint32_t mepc) {
    if ((mcause & MCAUSE_INT_MASK) && ((mcause & MCAUSE_CODE_MASK) == MCAUSE_MACHINE_EXT_INT)) {
        
        volatile uint32_t* claim_reg = (uint32_t*)PLIC_CLAIM_BASE;
        uint32_t irq_id = *claim_reg;

        if (irq_id == UART_IRQ_SOURCE_ID) {
            uart_isr();
        }

        *claim_reg = irq_id;
    }
}

int main()
{
    char received_char;

    init_uart();

    volatile uint32_t* plic_prio_reg = (uint32_t*)(PLIC_PRIORITY_BASE + (UART_IRQ_SOURCE_ID * 4));
    *plic_prio_reg = 1;

    volatile uint32_t* plic_enable_reg = (uint32_t*)(PLIC_ENABLE_BASE);
    *plic_enable_reg |= (1 << UART_IRQ_SOURCE_ID);

    volatile uint32_t* plic_threshold_reg = (uint32_t*)(PLIC_THRESHOLD_BASE);
    *plic_threshold_reg = 0;

    csr_write(0x305, (uint32_t)exc_wrapper);
    csr_write(CSR_MIE, csr_read(CSR_MIE) | MIE_MEIE_BIT);
    csr_write(CSR_MSTATUS, csr_read(CSR_MSTATUS) | MSTATUS_MIE_BIT);
    
    uart_enable_rx_irq();
    
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
            zputchar(received_char);
        }
    }

    return 0;
}
