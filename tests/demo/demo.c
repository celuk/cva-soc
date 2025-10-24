#include "uart.h"
#include "defines.h"

// --- CSR Addresses and Bitmasks ---
#define CSR_MSTATUS             0x300
#define CSR_MIE                 0x304
#define CSR_MTVEC               0x305
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

// --- The Combined Interrupt Handler and Dispatcher ---
// The 'interrupt' attribute tells the compiler to generate the full
// interrupt entry/exit code (saving/restoring registers and using 'mret').
// This completely replaces the need for 'exc_wrapper'.
void __attribute__((interrupt)) trap_handler_c(void) {
    uint32_t mcause_val = csr_read(CSR_MCAUSE);
    
    // Check if it's a Machine External Interrupt (from the PLIC)
    if ((mcause_val & MCAUSE_INT_MASK) && ((mcause_val & MCAUSE_CODE_MASK) == MCAUSE_MACHINE_EXT_INT)) {
        
        volatile uint32_t* claim_reg = (uint32_t*)PLIC_CLAIM_BASE;
        uint32_t irq_id = *claim_reg;

        // If an interrupt is pending (irq_id is not 0)
        if (irq_id) {
            // Service the interrupt (e.g., call the UART handler)
            if (irq_id == UART_IRQ_SOURCE_ID) {
                uart_isr();
            }

            // "Complete" the interrupt by writing the ID back. This must be done
            // after servicing to prevent race conditions.
            *claim_reg = irq_id;
        }
    }
}

int main()
{
    char received_char;

    init_uart();

    // --- PLIC and CPU Interrupt Setup ---
    volatile uint32_t* plic_prio_reg = (uint32_t*)(PLIC_PRIORITY_BASE + (UART_IRQ_SOURCE_ID * 4));
    *plic_prio_reg = 1;

    volatile uint32_t* plic_enable_reg = (uint32_t*)(PLIC_ENABLE_BASE);
    *plic_enable_reg |= (1 << UART_IRQ_SOURCE_ID);

    volatile uint32_t* plic_threshold_reg = (uint32_t*)(PLIC_THRESHOLD_BASE);
    *plic_threshold_reg = 0;

    // Set the Machine Trap Vector (mtvec) to our C handler's address
    csr_write(CSR_MTVEC, (uint32_t)trap_handler_c);

    // Enable Machine External Interrupts in the 'mie' CSR
    csr_write(CSR_MIE, csr_read(CSR_MIE) | MIE_MEIE_BIT);

    // Enable Global Interrupts in the 'mstatus' CSR
    csr_write(CSR_MSTATUS, csr_read(CSR_MSTATUS) | MSTATUS_MIE_BIT);
    
    // Enable the receiver interrupt within the UART peripheral itself
    uart_enable_rx_irq();
    
    tekno_printf("UART Interrupt Test Ready. Type characters:\n");

    while (1) {
        // zgetchar now waits for the software buffer to be filled by the ISR
        received_char = zgetchar();

        // Echo the character back
        zputchar(received_char);
    }

    return 0;
}
