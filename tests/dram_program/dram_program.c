#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

#include "gen_mem_blocks.h"

void write_all_dram_data(void) {
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
                dram_write(addr, block->data[i]);
                tekno_printf("Wrote data %x to address: %x\n", block->data[i], addr);
                bytes_written += 4;
            } else {
                // Handle partial word (last word might not be complete)
                unsigned int remaining = block->length - bytes_written;
                
                // For partial writes, we'll write the full word anyway since we're
                // working with 4-byte alignment in the data array
                dram_write(addr, block->data[i]);
                tekno_printf("Wrote data %x to address: %x\n", block->data[i], addr);
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
                    dram_write(end_addr_current + (i * 4), zero_data);
                    tekno_printf("Wrote data %x to address: %x\n", zero_data, end_addr_current + (i * 4));
                }
                // TODO: write FFFFFFFF to the end of the last block
            }
        }
    }
}

int main() {
    init_uart();

    tekno_printf("DRAM write started\n");

    wait_for_us(500);

    write_all_dram_data();
    
    tekno_printf("DRAM write done\n");

    return 0;
}
