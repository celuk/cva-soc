#include "uart.h"
#include "defines.h"

// --- CSR Addresses and Bitmasks ---
#define CSR_MSTATUS             0x300
#define CSR_MIE                 0x304
#define CSR_MCAUSE              0x342

#define MSTATUS_MIE_BIT         (1 << 3)  // Global Machine Interrupt Enable
#define MIE_MEIE_BIT            (1 << 11) // Machine External Interrupt Enable

#define MCAUSE_INT_MASK         0x80000000
#define MCAUSE_CODE_MASK        0x7FFFFFFF
#define MCAUSE_MACHINE_EXT_INT  11

// --- PLIC Register Definitions ---
#define PLIC_BASE_ADDR          0xFC000000
#define PLIC_PRIORITY_BASE      (PLIC_BASE_ADDR + 0x0)
#define PLIC_ENABLE_BASE        (PLIC_BASE_ADDR + 0x2000)
#define PLIC_THRESHOLD_BASE     (PLIC_BASE_ADDR + 0x200000)
#define PLIC_CLAIM_BASE         (PLIC_BASE_ADDR + 0x200004)

#define UART_IRQ_SOURCE_ID      1 // The UART is connected to source #1 on the PLIC

// --- Inline Assembly for CSR access ---
static inline void csr_write(uint32_t csr, uint32_t val) {
    __asm__ volatile("csrw %0, %1" : : "i"(csr), "r"(val));
}
static inline uint32_t csr_read(uint32_t csr) {
    uint32_t result;
    __asm__ volatile("csrr %0, %1" : "=r"(result) : "i"(csr));
    return result;
}

// --- The Main Interrupt Dispatcher ---
// This is the function called by your 'exc_wrapper' assembly.
void exception_handler(uint32_t mcause, uint32_t mepc) {
    // Check if it's an interrupt (MSB of mcause is 1)
    if (mcause & MCAUSE_INT_MASK) {
        // Check if it's a Machine External Interrupt (from the PLIC)
        if ((mcause & MCAUSE_CODE_MASK) == MCAUSE_MACHINE_EXT_INT) {
            
            // 1. Claim the interrupt from the PLIC to find out which device it is
            volatile uint32_t* claim_reg = (uint32_t*)PLIC_CLAIM_BASE;
            uint32_t irq_id = *claim_reg;

            // 2. Check if the interrupt source is the UART
            if (irq_id == UART_IRQ_SOURCE_ID) {
                // 3. Call the specific handler for the UART
                uart_isr();
            }

            // 4. "Complete" the interrupt by writing the ID back to the PLIC
            //    This tells the PLIC we are done, and it can send the next one.
            *claim_reg = irq_id;
        }
    } else {
        // It was an exception (e.g., illegal instruction), not an interrupt.
        print("Unhandled Exception!\n");
        while(1);
    }
}

int main()
{
    char received_char;

    init_uart();

    // --- PLIC and CPU Interrupt Setup ---

    // 1. Set the priority of the UART interrupt source to 1 (any non-zero value)
    volatile uint32_t* plic_prio_reg = (uint32_t*)(PLIC_PRIORITY_BASE + (UART_IRQ_SOURCE_ID * 4));
    *plic_prio_reg = 1;

    // 2. Enable the UART interrupt source within the PLIC
    volatile uint32_t* plic_enable_reg = (uint32_t*)(PLIC_ENABLE_BASE);
    *plic_enable_reg |= (1 << UART_IRQ_SOURCE_ID);

    // 3. Set the global interrupt priority threshold for this CPU core to 0
    volatile uint32_t* plic_threshold_reg = (uint32_t*)(PLIC_THRESHOLD_BASE);
    *plic_threshold_reg = 0;

    // 4. Enable Machine External Interrupts in the 'mie' CSR
    csr_write(CSR_MIE, csr_read(CSR_MIE) | MIE_MEIE_BIT);

    // 5. Enable Global Interrupts in the 'mstatus' CSR
    csr_write(CSR_MSTATUS, csr_read(CSR_MSTATUS) | MSTATUS_MIE_BIT);
    
    // 6. Enable the receiver interrupt within the UART peripheral itself
    uart_enable_rx_irq();

    print("UART Interrupt Test Ready. Type characters:\n");

    // --- Main Loop ---
    while(1) {
        // zgetchar now waits for the software buffer to be filled by the ISR
        received_char = zgetchar();
        
        // Echo the character back
        print("Echo: ");
        zputchar(received_char);
        print("\n");
    }

    return 0;
}
