#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

#include "gen_mem_blocks.h"

void write_all_dram_data(void) {
    unsigned int zero_data[4] = {0, 0, 0, 0}; // Four zero words for filling gaps
    unsigned int addr, i;
    unsigned int bytes_written;
    
    // Process each memory block
    for (int block_idx = 0; block_idx < NUM_MEMORY_BLOCKS; block_idx++) {
        const memory_block_t* block = &memory_blocks[block_idx];
        
        // Calculate the number of 16-byte chunks needed
        unsigned int chunks = (block->length + 15) / 16; // Round up division
        
        // Write the current block
        addr = block->address;
        bytes_written = 0;
        
        for (i = 0; i < chunks; i++) {
            unsigned int data0 = 0, data1 = 0, data2 = 0, data3 = 0;
            
            // Extract up to 4 words (16 bytes) from the block data
            unsigned int word_offset = i * 4; // 4 words per 16-byte chunk
            
            // Load data0 (first 4 bytes of chunk)
            if (bytes_written < block->length) {
                if (word_offset < (block->length + 3) / 4) {
                    data0 = block->data[word_offset];
                }
                bytes_written = (bytes_written + 4 > block->length) ? block->length : bytes_written + 4;
            }
            
            // Load data1 (second 4 bytes of chunk)
            if (bytes_written < block->length) {
                if (word_offset + 1 < (block->length + 3) / 4) {
                    data1 = block->data[word_offset + 1];
                }
                bytes_written = (bytes_written + 4 > block->length) ? block->length : bytes_written + 4;
            }
            
            // Load data2 (third 4 bytes of chunk)
            if (bytes_written < block->length) {
                if (word_offset + 2 < (block->length + 3) / 4) {
                    data2 = block->data[word_offset + 2];
                }
                bytes_written = (bytes_written + 4 > block->length) ? block->length : bytes_written + 4;
            }
            
            // Load data3 (fourth 4 bytes of chunk)
            if (bytes_written < block->length) {
                if (word_offset + 3 < (block->length + 3) / 4) {
                    data3 = block->data[word_offset + 3];
                }
                bytes_written = (bytes_written + 4 > block->length) ? block->length : bytes_written + 4;
            }
            
            // Write the 16-byte chunk
            dram_write_16bytes(addr, data0, data1, data2, data3);
            tekno_printf("Wrote data %x to address: %x\n", data0, addr);
            tekno_printf("Wrote data %x to address: %x\n", data1, addr+4);
            tekno_printf("Wrote data %x to address: %x\n", data2, addr+8);
            tekno_printf("Wrote data %x to address: %x\n", data3, addr+12);
            addr += 16;
        }
        
        // Fill gap between this block and the next one (if any)
        if (block_idx < NUM_MEMORY_BLOCKS - 1) {
            unsigned int end_addr_current = block->address + (chunks * 16);
            unsigned int start_addr_next = memory_blocks[block_idx + 1].address;
            
            // Calculate how many 16-byte chunks we need to fill the gap
            if (end_addr_current < start_addr_next) {
                unsigned int gap_size = start_addr_next - end_addr_current;
                unsigned int gap_chunks = gap_size / 16;
                
                // Fill the gap with zeros
                for (i = 0; i < gap_chunks; i++) {
                    dram_write_16bytes(end_addr_current + (i * 16), 
                                     zero_data[0], zero_data[1], 
                                     zero_data[2], zero_data[3]);
                    tekno_printf("Wrote data %x to address: %x\n", zero_data[0], end_addr_current + (i * 16));
                    tekno_printf("Wrote data %x to address: %x\n", zero_data[1], end_addr_current + (i * 16)+4);
                    tekno_printf("Wrote data %x to address: %x\n", zero_data[2], end_addr_current + (i * 16)+8);
                    tekno_printf("Wrote data %x to address: %x\n", zero_data[3], end_addr_current + (i * 16)+12);
                }
            }
        }
    }
    // address is already incremented in the last loop
    // Write the last 16 bytes with all ones to get recognized by bootloader
    dram_write_16bytes(addr, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
    tekno_printf("Wrote data %x to address: %x\n", 0xFFFFFFFF, addr);
    tekno_printf("Wrote data %x to address: %x\n", 0xFFFFFFFF, addr+4);
    tekno_printf("Wrote data %x to address: %x\n", 0xFFFFFFFF, addr+8);
    tekno_printf("Wrote data %x to address: %x\n", 0xFFFFFFFF, addr+12);
}

int main() {
    init_uart();
    init_timer();

    tekno_printf("DRAM write started\n");

    wait_for_us(500);

    write_all_dram_data();
    
    tekno_printf("DRAM write done\n");

    return 0;
}
