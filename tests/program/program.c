#include "qspi.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

#include "gen_mem_blocks.h"

void qspi_32byte_write(unsigned int* data, unsigned int addr){
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
    QSPI_DR1 = data[1];
    QSPI_DR2 = data[2];
    QSPI_DR3 = data[3];
    QSPI_DR4 = data[4];
    QSPI_DR5 = data[5];
    QSPI_DR6 = data[6];
    QSPI_DR7 = data[7];

    QSPI_ADR = addr;
    qspi_set_ccr(
        /*inst_value*/       CMD_QPP,
        /*data_mod*/         3,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
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

    tekno_printf("Wrote 32 bytes to address: %x\n", addr);

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
    unsigned int zero_data[8] = {0}; // Buffer of zeros for filling gaps
    unsigned int temp_buffer[8]; // Temporary buffer for partial writes
    unsigned int addr, i, j;
    unsigned int bytes_written;
    
    // Process each memory block
    for (int block_idx = 0; block_idx < NUM_MEMORY_BLOCKS; block_idx++) {
        const memory_block_t* block = &memory_blocks[block_idx];
        
        // Calculate the number of 32-byte chunks needed
        unsigned int chunks = (block->length + 31) / 32; // Round up division
        
        // Write the current block
        addr = block->address;
        bytes_written = 0;
        
        for (i = 0; i < chunks; i++) {
            // Check if we have a full chunk
            if (bytes_written + 32 <= block->length) {
                // Write a full chunk
                qspi_32byte_write(&block->data[i * 8], addr);
                bytes_written += 32;
            } else {
                // Handle partial chunk (last chunk might not be complete)
                unsigned int remaining = block->length - bytes_written;
                unsigned int words_to_copy = (remaining + 3) / 4; // Number of whole words
                
                // Clear temp buffer
                for (j = 0; j < 8; j++) {
                    temp_buffer[j] = 0;
                }
                
                // Copy remaining data
                for (j = 0; j < words_to_copy; j++) {
                    temp_buffer[j] = block->data[i * 8 + j];
                }
                
                qspi_32byte_write(temp_buffer, addr);
                bytes_written += remaining;
            }
            
            addr += 32;
        }
        
        // Fill gap between this block and the next one (if any)
        if (block_idx < NUM_MEMORY_BLOCKS - 1) {
            unsigned int end_addr_current = block->address + ((chunks * 32) > block->length ? 
                                          (chunks * 32) : block->length);
            unsigned int start_addr_next = memory_blocks[block_idx + 1].address;
            
            // Calculate how many 32-byte chunks we need to fill the gap
            if (end_addr_current < start_addr_next) {
                unsigned int gap_size = start_addr_next - end_addr_current;
                unsigned int gap_chunks = gap_size / 32;
                
                // Fill the gap with zeros
                for (i = 0; i < gap_chunks; i++) {
                    qspi_32byte_write(zero_data, end_addr_current + (i * 32));
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

    QSPI_ADR = 0x00001c00;
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
