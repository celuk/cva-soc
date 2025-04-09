#include "qspi.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

#include "gen_mem_blocks.h"

void qspi_4byte_write(unsigned int* data, unsigned int addr){
    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_DR0 = data[0];

    QSPI_ADR = addr;
    qspi_set_ccr(
        /*inst_value*/       CMD_QPP,
        /*data_mod*/         3,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        3,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    tekno_printf("Wrote 4 bytes to address: %x\n", addr);

    //if(addr == 0x00001c00) {
    //    tekno_printf("data0: %x\n", data[0]);
    //    tekno_printf("data1: %x\n", data[1]);
    //    tekno_printf("data2: %x\n", data[2]);
    //    tekno_printf("data3: %x\n", data[3]);
    //    tekno_printf("data4: %x\n", data[4]);
    //    tekno_printf("data5: %x\n", data[5]);
    //    tekno_printf("data6: %x\n", data[6]);
    //    tekno_printf("data7: %x\n", data[7]);
    //}
}

void write_all_flash_data(void) {
    unsigned int zero_data = 0; // Single zero word for filling gaps
    unsigned int temp_buffer; // Temporary buffer for partial writes
    unsigned int addr, i;
    unsigned int bytes_written;
    
    // Process each memory block
    for (int block_idx = 0; block_idx < NUM_MEMORY_BLOCKS; block_idx++) {
        const memory_block_t* block = &memory_blocks[block_idx];
        
        // Calculate the number of words (4-byte chunks) needed
        unsigned int words = (block->length + 3) / 4; // Round up division
        
        // Write the current block
        addr = block->address;
        bytes_written = 0;
        
        for (i = 0; i < words; i++) {
            // Check if we have a full word
            if (bytes_written + 4 <= block->length) {
                // Write a full word
                qspi_4byte_write(&block->data[i], addr);
                bytes_written += 4;
            } else {
                // Handle partial word (last word might not be complete)
                unsigned int remaining = block->length - bytes_written;
                
                // For partial writes, we'll write the full word anyway since we're
                // working with 4-byte alignment in the data array
                qspi_4byte_write(&block->data[i], addr);
                bytes_written += remaining;
            }
            
            addr += 4;
        }
        
        // Fill gap between this block and the next one (if any)
        if (block_idx < NUM_MEMORY_BLOCKS - 1) {
            unsigned int end_addr_current = block->address + ((words * 4) > block->length ? 
                                          (words * 4) : block->length);
            unsigned int start_addr_next = memory_blocks[block_idx + 1].address;
            
            // Calculate how many 4-byte words we need to fill the gap
            if (end_addr_current < start_addr_next) {
                unsigned int gap_size = start_addr_next - end_addr_current;
                unsigned int gap_words = gap_size / 4;
                
                // Fill the gap with zeros
                for (i = 0; i < gap_words; i++) {
                    qspi_4byte_write(&zero_data, end_addr_current + (i * 4));
                }
            }
        }
    }
}

int main() {

    init_uart();

    tekno_printf("QSPI write started\n");

    wait_for_us(500);

    qspi_set_ccr(
        /*inst_value*/       CMD_RESET,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    wait_for_us(500);

    qspi_enable_quad_mode();

    //QSPI_DR0 = 0xbbbbbbbb;
    //QSPI_DR1 = 0xbbbbbbbb;
    //QSPI_DR2 = 0xbbbbbbbb;
    //QSPI_DR3 = 0xbbbbbbbb;
    //QSPI_DR4 = 0xbbbbbbbb;
    //QSPI_DR5 = 0xbbbbbbbb;
    //QSPI_DR6 = 0xbbbbbbbb;
    //QSPI_DR7 = 0xbbbbbbbb;
//
    //QSPI_ADR = 0x00000000;
    //qspi_set_ccr(
    //    /*inst_value*/       CMD_QPP,
    //    /*data_mod*/         3,
    //    /*wr_flash*/         1,
    //    /*dummy_cycle*/      0,
    //    /*data_size*/        31,
    //    /*prescaler*/        1,
    //    /*clear_status_reg*/ 1
    //);
    //wait_for_not_busy();
    //wait_for_wip_done();

    //qspi_set_ccr(
    //    /*inst_value*/       CMD_WRDI,
    //    /*data_mod*/         1,
    //    /*wr_flash*/         0,
    //    /*dummy_cycle*/      0,
    //    /*data_size*/        0,
    //    /*prescaler*/        1,
    //    /*clear_status_reg*/ 1
    //);
    //wait_for_not_busy();
    //wait_for_wel_down();

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    // clears 64 or 256kB??
    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_SE,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    //QSPI_ADR = 0x00001c00;
    QSPI_ADR = 0x00007000;
    qspi_set_ccr(
        /*inst_value*/       CMD_SE,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    // clears 64 or 256kB??
    QSPI_ADR = 0x00010000;
    qspi_set_ccr(
        /*inst_value*/       CMD_SE,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    write_all_flash_data();
    
    tekno_printf("QSPI write done\n");

    return 0;
}
